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
    DecryptedBid[] private _winnerBids;

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

        // Expect euint256 values
        euint256 encryptedAmount = TFHE.asEuint256(amount, inputProof);
        euint256 encryptedPricePer = TFHE.asEuint256(pricePer, inputProof);

        // Get the expected total amount to be paid
        euint256 encryptedAmountToPay = TFHE.mul(encryptedAmount, encryptedPricePer);
        TFHE.allowTransient(encryptedAmountToPay, address(msg.sender));
        euint256 m = TFHE.mul(_secretMultiplier, encryptedAmountToPay);

        // This fails w/ 'sender isn't allowed'
        // Switched to multiplying the amountToPay w/ a random secret to hide the data
        // I can check by multiplying the threshold w/ the secret and compare
        // TFHE.allowTransient(_total, msg.sender);
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
                locked: msg.value,
                bidTime: block.timestamp,
                amount: encryptedAmount,
                pricePer: encryptedPricePer
            })
        );

        // Allow contract owner to decrypt total and price
        TFHE.allow(_bids[_bids.length - 1].amount, owner());
        TFHE.allow(_bids[_bids.length - 1].pricePer, owner());
        _lastBid += 1;

        _nfts.push(tokenId);

        emit BidCreated(msg.sender);

        return tokenId;
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
        _decryptBids();
    }

    function _distributeWinnerNfts() private {
        uint256 i = 0;
        uint256 total = 0;
        uint256 finalPricePer;
        while (total < settlePrice) {
            total += _winnerBids[i].amount * _winnerBids[i].pricePer;
            winnerNFT.createWinner(_winnerBids[i].bidder, id, _nfts[_winnerBids[i].bidId]);
            finalPricePer = _winnerBids[i].pricePer;
            i++;
        }
        finalTokenPricePer = finalPricePer;
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
     *  @notice Gateway to decrypt if a single bid met the settel price
     * @param multipliedTotal_ Total multiplied by secret
     */
    function gatewaydecryptBidTotalValue(uint256 requestId, uint256 multipliedTotal_) public onlyGateway {
        _multipliedTotal += multipliedTotal_;
        euint256 encryptedTotal = TFHE.asEuint256(_multipliedTotal);
        // Instead of adding up the values and storing it in a global variable,
        // we multiply each value by a secret value and decrypt the value (amount * pricePer * secret) and add to the total in plaintext
        // This does not leak the value, since the comparison happens under FHE, but it is less efficient
        // I was unable to update a global euint256 "sender isn't allowed"
        euint256 encryptedSettlePrice = TFHE.asEuint256(settlePrice);
        ebool thresholdMet = TFHE.select(
            TFHE.gt(encryptedTotal, TFHE.mul(encryptedSettlePrice, _secretMultiplier)),
            TFHE.asEbool(true),
            TFHE.asEbool(false)
        );
        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(thresholdMet);
        Gateway.requestDecryption(cts, this.gatewayDecryptThreshold.selector, 0, block.timestamp + 100, false);

        delete _decryptions[requestId];
        _decryptionsNo--;
    }

    /**
     *
     * @notice Check if bid met settle price
     * @dev Refund bid if necessary
     */
    function gatewayDecryptThreshold(uint256 requestId, bool result) public onlyGateway {
        if (result) {
            console.log("Settle price met");
            updateAuction();
            emit SettlePriceMet();
            if (config.shouldTerminateWhenSettlePricedMet()) {
                _refundBidder(requestId);
                _decryptBids();
                return;
            }
        }
    }

    function _decryptBids() private onlyOwner finishedAuction {
        for (uint i = 0; i < _bids.length; i++) {
            uint256[] memory cts = new uint256[](2);
            cts[0] = Gateway.toUint256(_bids[i].amount);
            cts[1] = Gateway.toUint256(_bids[i].pricePer);
            uint256 requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptBid.selector,
                0,
                block.timestamp + 100,
                false
            );
            _accounting[requestId];
        }
    }

    function gatewayDecryptBid(uint256 requestId, uint256 amount, uint256 pricePer) public onlyGateway {
        uint256 bidId = _accounting[requestId];
        _winnerBids.push(
            DecryptedBid({
                bidId: bidId,
                bidder: _bids[bidId].bidder,
                locked: _bids[bidId].locked,
                bidTime: _bids[bidId].bidTime,
                amount: amount,
                pricePer: pricePer
            })
        );

        if (_winnerBids.length == _bids.length) {
            _sortWinningBids();
            _distributeWinnerNfts();
        }
    }

    function _sortWinningBids() private {
        uint256 len = _winnerBids.length;
        for (uint256 i = 0; i < len; i++) {
            for (uint256 j = 0; j < len - 1; j++) {
                uint256 valueA = _winnerBids[j].amount * _winnerBids[j].pricePer;
                uint256 valueB = _winnerBids[j + 1].amount * _winnerBids[j + 1].pricePer;

                // Swap if the next bid has a higher value
                if (valueB > valueA) {
                    DecryptedBid memory temp = _winnerBids[j];
                    _winnerBids[j] = _winnerBids[j + 1];
                    _winnerBids[j + 1] = temp;
                }
            }
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

    function getFinalTokenPricePer() external view returns (uint256) {
        return finalTokenPricePer;
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
}
