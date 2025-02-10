//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import { TFHE, einput, ebool, euint4, eaddress, euint256 } from "fhevm/lib/TFHE.sol";
import { AuctionConfig } from "./AuctionConfig.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AssetType, AuctionFactory } from "./AuctionFactory.sol";
import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";
import { IConfidentialAuction } from "./interfaces/IConfidentialAuction.sol";
import { AuctionPosition } from "./AuctionPosition.sol";
import { AuctionWinner } from "./AuctionWinner.sol";
import "fhevm/gateway/GatewayCaller.sol";

contract ConfidentialAuction is
    IConfidentialAuction,
    Ownable,
    SepoliaZamaFHEVMConfig,
    SepoliaZamaGatewayConfig,
    GatewayCaller
{
    AuctionConfig config;
    AuctionFactory parent;

    string private auctionName;

    uint256 private endAuctionTime;
    bool private _didAuctionFinish = true;
    bool private _didAuctionStart = false;
    bool private _didAuctionTerminate = false;
    bool private _didWinnersCalculated = false;
    bool private _isSettlePriceMet = false;

    // tokenId -> bidId
    uint256[] private _nfts;
    Bid[] _bids;
    // bidIds that won the auction
    Bid[] private _winnerBids;

    DecryptedBid[] _decryptedBids;

    uint256 private _lastBidWinner;

    mapping(uint256 => uint256) private _accounting;
    uint256 private _pendingAccountingDecryptions;
    mapping(uint256 => address) private _decryptions;
    uint256 private _decryptionsNo;

    uint256 private settlePrice;
    uint256 private id;

    AuctionPosition positionNFT;
    AuctionWinner winnerNFT;

    // Last bid that was part of the calculations
    uint256 private _bidsCalculated;

    // For some reason cannot modify a _total counter if it is defined here
    euint4 private _secretMultiplier;
    uint256 private _multipliedTotal;
    euint256 private _total;

    uint256 private _lastBid = 0;

    uint256 private finalTokenPricePer;

    constructor(
        uint256 _id,
        string memory _auctionName,
        uint256 _settlePrice,
        address position,
        address winner
    ) Ownable(tx.origin) {
        auctionName = _auctionName;
        settlePrice = _settlePrice;
        id = _id;
        _secretMultiplier = TFHE.randEuint4();
        TFHE.allowThis(_secretMultiplier);
        TFHE.allow(_secretMultiplier, msg.sender);

        _total = TFHE.asEuint256(0);
        TFHE.allowThis(_total);
        TFHE.allow(_total, msg.sender);

        config = new AuctionConfig(address(this));
        parent = AuctionFactory(msg.sender);
        positionNFT = AuctionPosition(position);
        winnerNFT = AuctionWinner(winner);
    }

    modifier activeAuction() {
        if (
            // block.timestamp >= config.finishTime() &&
            _didAuctionFinish && !_didAuctionStart && _didAuctionTerminate
        ) {
            revert ClosedAuction();
        }
        _;
    }

    modifier unstartedAuction() {
        if (
            // block.timestamp < config.finishTime() ||
            _didAuctionStart && !_didAuctionFinish && _didAuctionTerminate
        ) {
            revert StartedAuction("Auction already started");
        }
        _;
    }

    modifier finishedAuction() {
        if (block.timestamp < config.finishTime() && !_didAuctionFinish) {
            revert NotFinishedAuction();
        }
        _;
    }

    modifier terminatedAuction() {
        if (_didAuctionTerminate) {
            revert LiveAuction();
        }
        _;
    }

    function didAuctionStart() public view returns (bool) {
        return _didAuctionStart;
    }

    /**
     *
     * @notice Create a confidential bid
     * @param amount Encrypted amounts of token
     * @param pricePer Encrypted price per token
     */
    function bid(
        einput amount,
        einput pricePer,
        bytes calldata inputProof
    ) external payable override activeAuction returns (uint256) {
        if (config.shouldLockFunds() && msg.value < config.lockAmount()) {
            revert FundLockNotMet(config.lockAmount());
        }

        euint256 encryptedSettlePrice = TFHE.asEuint256(settlePrice);

        // Expect euint256 values
        euint256 encryptedAmount = TFHE.asEuint256(amount, inputProof);
        euint256 encryptedPricePer = TFHE.asEuint256(pricePer, inputProof);

        // Allow the smart contract to decrypt those data for the resolution phase
        TFHE.allowThis(encryptedAmount);
        TFHE.allowThis(encryptedPricePer);

        TFHE.allowThis(encryptedSettlePrice);
        // Get the expected total amount to be paid
        euint256 encryptedAmountToPay = TFHE.mul(encryptedAmount, encryptedPricePer);
        TFHE.allowTransient(encryptedAmountToPay, address(msg.sender));
        euint256 m = TFHE.mul(_secretMultiplier, encryptedAmountToPay);

        // This fails w/ 'sender isn't allowed'
        // Switched to multiplying the amountToPay w/ a random secret to hide the data
        // I can check by multiplying the threshold w/ the secret and compare
        // TFHE.allowTransient(_total, address(msg.sender));
        // _total = TFHE.add(_total, encryptedAmountToPay);

        // Request to decrypt the total amount to be able to verify and confirm the bid
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(m);
        uint256 requestId = Gateway.requestDecryption(
            cts,
            this.gatewaydecryptBidTotalValue.selector,
            0,
            block.timestamp + 100,
            false
        );
        _decryptions[requestId] = msg.sender;
        _decryptionsNo++;

        uint256 tokenId = positionNFT.createBidPosition(msg.sender, id);
        _bids.push(
            Bid({
                bidder: msg.sender,
                bidTime: block.timestamp,
                amount: encryptedAmount,
                pricePer: encryptedPricePer,
                total: encryptedAmountToPay
            })
        );
        TFHE.allow(_bids[_bids.length - 1].total, owner());
        _lastBid += 1;
        // This throws error 'sender isn't allowed'
        // I think Bid struct contains encrypted values but I only want the length of the array?
        // _lastBid = _bids.length - 1;
        // _lastBid = tokenId;

        _nfts.push(tokenId);

        emit BidCreated(msg.sender);

        return tokenId;

        return 1;
    }

    /**
     * @notice Start auction, only called by owner
     */
    function startAuction() public onlyOwner unstartedAuction {
        // Finalized config, if config modifiable will still be able to configure when auction is live
        config.finalizeConfig();
        _didAuctionStart = true;
        emit AuctionStarted(address(this));
    }

    /**
     * @notice Terminate auction, only called by owner
     */
    function terminateAuction(string memory terminationMessage) public onlyOwner {
        // Finalized config, if config modifiable will still be able to configure when auction is live
        config.finalizeConfig();
        _didAuctionTerminate = true;
        emit AuctionTerminated(terminationMessage);
    }

    /**
     * @notice Finish auction, only called by owner
     */
    function finishAuction() public onlyOwner activeAuction {
        _didAuctionFinish = true;
        if (!_didWinnersCalculated) {
            _calculateBidWinners();
        }
    }

    /**
     * @notice Calculates the winners of the bid and the token price
     * @dev Sort by total (i.e. amount*pricePer)
     */
    function _calculateBidWinners() private onlyOwner finishedAuction {
        _bidsCalculated = _nfts.length;
        _didWinnersCalculated = true;

        uint256[] memory cts = new uint256[](1);
        for (uint256 i = 0; i < _bids.length; i++) {
            euint256 _t = TFHE.asEuint256(0);
            TFHE.allowThis(_t);
            // TFHE.allowTransient(_bids[i].total, msg.sender);
            console.log("here");
            for (uint256 j = 0; j < _lastBid; j++) {
                // msg.owner which is the auction owner is allowed to these values, however the comparions throw 'Sender doesn't own lhs on op'
                console.log(i, j, TFHE.isSenderAllowed(_bids[i].total), TFHE.isSenderAllowed(_bids[j].total));
                // TFHE.allowThis(_bids[j].total);
                if (i == j) {
                    continue;
                }
                euint256 isBigger = TFHE.select(
                    TFHE.gt(_bids[i].total, _bids[j].total),
                    TFHE.asEuint256(1),
                    TFHE.asEuint256(0)
                );
                _t = TFHE.add(_t, isBigger);
            }

            cts[0] = Gateway.toUint256(_t);
            uint256 requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptAccounting.selector,
                0,
                block.timestamp + 100,
                false
            );
            _pendingAccountingDecryptions += 1;
            _accounting[requestId] = i;
        }
    }

    /**
     * @notice Iterate over the sorted bids(by total) and add up the values
     * Each iteration checks if the added values meet the settel price
     * If threshold met, we have the winning bids
     */
    function _calculateBidWinners2() public {
        uint256[] memory cts = new uint256[](1);
        euint256 encryptedSettlePrice;
        encryptedSettlePrice = TFHE.asEuint256(settlePrice);
        euint256 _t = TFHE.asEuint256(0);

        for (uint256 i = 0; i < _winnerBids.length; i++) {
            _t = TFHE.add(_winnerBids[i].total, _t);
            ebool thresholdMet = TFHE.select(
                TFHE.gt(_t, encryptedSettlePrice),
                TFHE.asEbool(true),
                TFHE.asEbool(false)
            );
            cts[0] = Gateway.toUint256(thresholdMet);
            uint256 requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptWinners.selector,
                0,
                block.timestamp + 100,
                false
            );
            _accounting[requestId] = i;
            _pendingAccountingDecryptions += 1;
        }
    }

    function _distributeWinnerNfts() private {
        for (uint256 i = 0; i < _lastBidWinner; i++) {
            winnerNFT.createWinner(_bids[i].bidder, id, _nfts[i]);
        }
        emit AuctionWinnersAnnounced();
        _didAuctionFinish = true;
    }

    /**
     * @notice Update auction state
     * @dev Calls calculate bid winner
     */
    function updateAuction() public override {
        if (_bidsCalculated == _nfts.length) {
            // Nothing to do
            return;
        }
        if (_isSettlePriceMet && config.shouldTerminateWhenSettlePricedMet()) {
            _calculateBidWinners();
            finishAuction();
        }
        if (block.timestamp > config.finishTime()) {
            _calculateBidWinners();
        }
    }

    /**
     * @notice Refund bidder if erronously submitted a bid
     * @dev This is necessary due to async decryption
     * @param requestId Bid to refund
     */
    function _refundBidder(uint256 requestId) private {
        address recipient = _decryptions[requestId];
        // TODO msg.value -> bid.lockedAmount
        (bool success, ) = recipient.call{ value: msg.value }("");
        require(success, "Call failed");
    }

    /**
     *  @notice Gateway to decrypt if a single bid met the settel price
     * @param multipliedTotal_ Total multiplied by secret
     */
    function gatewaydecryptBidTotalValue(uint256 requestId, uint256 multipliedTotal_) public onlyGateway {
        // Due to async threshold has been met while decryption

        _multipliedTotal += multipliedTotal_;
        // TODO encrypt this ^ and decrypt to check if met
        // if (_isSettlePriceMet && config.shouldTerminateWhenSettlePricedMet()) {
        //     _refundBidder(requestId);
        //     return;
        // }
        // if (result) {
        //     updateAuction();
        //     emit SettlePriceMet();
        // }
        delete _decryptions[requestId];
        _decryptionsNo--;
    }

    function _decryptWinnerBid(uint256 bidId) private {
        uint256[] memory cts = new uint256[](1);
        // TODO price = amount*pricePer - lockedAmount
        // amount
        cts[0] = Gateway.toUint256(_bids[bidId].);
        uint256 requestId = Gateway.requestDecryption(
            cts,
            this.gatewaydecryptBidTotalValue.selector,
            0,
            block.timestamp + 100,
            false
        );
        // TODO Move into gateway
        // _distributeWinnerNft();
    }

    /**
     *
     * @notice Gateway to decrypt "accounting" values used to get winners
     */
    function gatewayDecryptAccounting(uint256 requestId, uint256 result) public onlyGateway {
        _winnerBids[result] = _bids[_accounting[requestId]];
        _pendingAccountingDecryptions -= 1;

        console.log("accounting");
        if (_pendingAccountingDecryptions == 0) {
            _calculateBidWinners2();
        }
    }

    /**
     *
     * @notice Called by second step in winner calculation
     */
    function gatewayDecryptWinners(uint256 requestId, bool result) public onlyGateway {
        _pendingAccountingDecryptions -= 1;
        _decryptWinnerBid(_lastBidWinner);
        if (result) {
            _didWinnersCalculated = true;
            _lastBidWinner = _accounting[requestId];
        }
    }

    /**
     * @notice Auction status getter
     */
    function getAuction() external view returns (AuctionStatus memory) {
        return
            AuctionStatus(
                auctionName,
                _didAuctionFinish,
                _didAuctionStart,
                _didAuctionTerminate,
                _didWinnersCalculated,
                _isSettlePriceMet,
                _bids.length,
                settlePrice,
                id
            );
    }

    /**
     * @notice Get config address
     */
    function getConfig() external view returns (address) {
        return address(config);
    }

    /**
     *
     * @notice Get decrypted bid, after winners calculated
     */
    function getDecryptedBid(uint256 tokenId) external view returns (DecryptedBid memory) {
        uint256 bidId = _nfts[tokenId];
        return _decryptedBids[bidId];
    }

    /**
     *
     * @notice Check if bid met settle price
     * @dev Refund bid if necessary
     */
    function gatewaydecryptMet(uint256 requestId, bool result) external {}
}
