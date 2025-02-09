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

    uint256 settlePrice;
    uint256 id;

    AuctionPosition positionNFT;
    AuctionWinner winnerNFT;

    // Last bid that was part of the calculations
    uint256 private _bidsCalculated;

    // For some reason cannot modify a _total counter if it is defined here
    euint4 private _secretMultiplier;
    uint256 private _multipliedTotal;
    euint256 private _total;

    constructor(uint256 _id, string memory auctionName, AssetType assetType, uint256 _settlePrice) Ownable(tx.origin) {
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
        positionNFT = parent.getPositionNFT();
        winnerNFT = parent.getWinnerNFT();
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
        if (block.timestamp >= config.finishTime() || _didAuctionFinish) {
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

    // Create a bid
    // Mints a transferrable NFT
    function bid(
        einput amount,
        einput pricePer,
        bytes calldata inputProof
    ) external payable override activeAuction returns (uint256) {
        if (config.shouldLockFunds() && msg.value < config.lockAmount()) {
            console.log(config.lockAmount());
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
        TFHE.allowThis(encryptedAmountToPay);
        euint256 m = TFHE.mul(_secretMultiplier, encryptedAmountToPay);

        // This fails w/ 'sender isn't allowed'
        // Switched to multiplying the amountToPay w/ a random secret to hide the data
        // I can check by multiplying the threshold w/ the secret and compare
        TFHE.allowTransient(_total, address(msg.sender));
        _total = TFHE.add(_total, encryptedAmountToPay);

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
        // WTF?
        // This throws error 'sender isn't allowed'
        // I think Bid struct contains encrypted values but I only want the length of the array?
        // _lastBid = _bids.length - 1;
        // _lastBid = tokenId;

        _nfts.push(tokenId);

        emit BidCreated(msg.sender);

        return tokenId;
    }

    function startAuction() public onlyOwner unstartedAuction {
        // Finalized config, if config modifiable will still be able to configure when auction is live
        config.finalizeConfig();
        _didAuctionStart = true;
        emit AuctionStarted(address(this));
    }

    function terminateAuction(string memory terminationMessage) public onlyOwner {
        // Finalized config, if config modifiable will still be able to configure when auction is live
        config.finalizeConfig();
        _didAuctionTerminate = true;
        emit AuctionTerminated(terminationMessage);
    }

    function finishAuction() public onlyOwner activeAuction {
        if (!_didWinnersCalculated) {
            _calculateBidWinners();
        }
    }

    function _calculateBidWinners() private {
        _bidsCalculated = _nfts.length;
        _didWinnersCalculated = true;

        uint256[] memory cts = new uint256[](1);
        for (uint256 i = 0; i < _bids.length; i++) {
            euint256 _total = TFHE.asEuint256(0);
            for (uint256 j = 0; j < _bids.length; j++) {
                if (i == j) {
                    continue;
                }
                euint256 isBigger = TFHE.select(
                    TFHE.gt(_bids[i].total, _bids[j].total),
                    TFHE.asEuint256(1),
                    TFHE.asEuint256(0)
                );
                _total = TFHE.add(_total, isBigger);
            }
            cts[0] = Gateway.toUint256(_total);
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

    function _calculateBidWinners2() public {
        uint256[] memory cts = new uint256[](1);
        euint256 encryptedSettlePrice;
        encryptedSettlePrice = TFHE.asEuint256(settlePrice);
        euint256 _total = TFHE.asEuint256(0);

        for (uint256 i = 0; i < _winnerBids.length; i++) {
            _total = TFHE.add(_winnerBids[i].total, _total);
            ebool thresholdMet = TFHE.select(
                TFHE.gt(_total, encryptedSettlePrice),
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
            winnerNFT.createWinner(_bids[i].bidder, id);
        }
        emit AuctionWinnersAnnounced();
        _didAuctionFinish = true;
    }

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

    function _refundBidder(uint256 requestId) private {
        address recipient = _decryptions[requestId];
        (bool success, ) = recipient.call{ value: msg.value }("");
        require(success, "Call failed");
    }

    function gatewaydecryptBidTotalValue(uint256 requestId, uint256 multipliedTotal_) public onlyGateway {
        // Due to async threshold has been met while decryption
        if (_isSettlePriceMet && config.shouldTerminateWhenSettlePricedMet()) {
            _refundBidder(requestId);
            return;
        }
        console.log("here");
        _multipliedTotal += multipliedTotal_;
        // if (result) {
        //     updateAuction();
        //     emit SettlePriceMet();
        // }
        delete _decryptions[requestId];
        _decryptionsNo--;
    }

    function gatewayDecryptAccounting(uint256 requestId, uint256 result) public onlyGateway {
        _winnerBids[result] = _bids[_accounting[requestId]];
        _pendingAccountingDecryptions -= 1;

        console.log("accounting");
        if (_pendingAccountingDecryptions == 0) {
            _calculateBidWinners2();
        }
    }

    function gatewayDecryptWinners(uint256 requestId, bool result) public onlyGateway {
        _pendingAccountingDecryptions -= 1;
        console.log("winner");
        if (result) {
            _didWinnersCalculated = true;
            _lastBidWinner = _accounting[requestId];
            _distributeWinnerNfts();
        }
    }

    function getAuction() external view returns (AuctionStatus memory) {
        return
            AuctionStatus(
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

    function getConfig() external view returns (address) {
        return address(config);
    }

    function getDecryptedBid(uint256 tokenId) external view returns (DecryptedBid memory) {
        uint256 bidId = _nfts[tokenId];
        return _decryptedBids[bidId];
    }

    function gatewaydecryptMet(uint256 requestId, bool result) external {}
}
