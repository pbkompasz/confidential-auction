//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { TFHE, einput, ebool, euint4, eaddress, euint256 } from "fhevm/lib/TFHE.sol";

interface IConfidentialAuction {
    error ClosedAuction();
    error StartedAuction(string);
    error NotFinishedAuction();
    error LiveAuction();
    error FundLockNotMet(uint256);

    event BidCreated(address);
    event AuctionStarted(address);
    event AuctionTerminated(string);
    event SettlePriceMet();
    event AuctionWinnersAnnounced();

    struct Bid {
        address bidder;
        uint256 locked;
        uint256 bidTime;
        euint256 amount;
        euint256 pricePer;
    }

    struct DecryptedBid {
        uint256 bidId;
        address bidder;
        uint256 locked;
        uint256 bidTime;
        uint256 pricePer;
        uint256 amount;
    }

    struct AuctionStatus {
        string auctionName;
        bool didAuctionFinish;
        bool didAuctionStart;
        bool didAuctionTerminate;
        bool didWinnersCalculated;
        bool isSettlePriceMet;
        uint256 bids;
        uint256 settlePrice;
        uint256 id;
    }

    function startAuction() external;

    function terminateAuction(string memory) external;

    function bid(einput, einput, bytes calldata) external payable returns (uint256);

    // function getAuction() external view returns (AuctionStatus memory);

    function updateAuction() external;

}
