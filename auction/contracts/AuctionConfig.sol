//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import { TFHE, euint4, eaddress } from "fhevm/lib/TFHE.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AssetType } from "./AuctionFactory.sol";
import { ConfidentialAuction } from "./ConfidentialAuction.sol";

enum ResolutionStrategy {
    FIFO,
    SPLIT
}

contract AuctionConfig is Ownable {
    error AlreadyFinalized();
    error NotModifiable();
    error NotOwner();

    ConfidentialAuction auction;

    // whether an address can participate more than once
    address[] private _addressBlacklist;

    // whether a user can modify an existing bid before the auction end
    bool private _isConfigModifiable = true;

    // how long the auction should last or when it should end
    uint16 private _duration = 1000; //blocks
    uint256 private _finishTime;

    // how to determine the proper resolution if the two lowest bids are equal
    ResolutionStrategy private _bidConfigResolutionStrategy = ResolutionStrategy.FIFO;

    // how to prevent participation in an auction without the funds (i.e. the locking mechanism)
    bool private _shouldLockFunds = true;
    uint64 private _lockAmount = 1000000000000000; //inWei

    // Max per bids user
    uint8 private _maxPerUser = 5;

    // This shouldn't be here
    bool private _isFinalized = false;

    bool private _shouldTerminateWhenSettlePricedMet = true;

    struct Config {
        bool hasBlacklists;
        bool isConfigModifiable;
        uint256 duration;
        uint256 finishTime;
        ResolutionStrategy bidConfigResolutionStrategy;
        bool shouldlockFunds;
        uint256 lockAmount;
        uint256 maxBidsPerUser;
        bool isConfigFinalized;
        bool shouldTerminateWhenSettlePricedMet;
    }

    constructor(address _auction) Ownable(tx.origin) {
        auction = ConfidentialAuction(_auction);
    }

    modifier onlyIfModifiable() {
        if ((auction.didAuctionStart() && !_isConfigModifiable) || (_isFinalized && !_isConfigModifiable)) {
            revert NotModifiable();
        }
        _;
    }

    modifier onlyOnce() {
        if (owner() != tx.origin) {
            revert NotOwner();
        }
        if (_isFinalized && _isConfigModifiable) {
            revert AlreadyFinalized();
        }
        _;
    }

    function addressBlacklist() public view returns (address[] memory) {
        return _addressBlacklist;
    }

    function isFinalized() public view returns (bool) {
        return _isFinalized;
    }

    function isConfigModifiable() public view returns (bool) {
        return _isConfigModifiable;
    }

    // function duration() public view returns (uint16) {
    //     return _duration;
    // }

    function lockAmount() public view returns (uint256) {
        return _lockAmount;
    }

    // function bidConfigResolutionStrategy() public view returns (ResolutionStrategy) {
    //     return _bidConfigResolutionStrategy;
    // }

    function shouldLockFunds() public view returns (bool) {
        return _shouldLockFunds;
    }

    // function maxPerUser() public view returns (uint8) {
    //     return _maxPerUser;
    // }

    function finishTime() public view returns (uint256) {
        return _finishTime;
    }

    function shouldTerminateWhenSettlePricedMet() public view returns (bool) {
        return _shouldTerminateWhenSettlePricedMet;
    }

    function getConfig() public view returns (Config memory) {
        return
            Config(
                _addressBlacklist.length > 0,
                _isConfigModifiable,
                _duration,
                _finishTime,
                _bidConfigResolutionStrategy,
                _shouldLockFunds,
                _lockAmount,
                _maxPerUser,
                _isFinalized,
                _shouldTerminateWhenSettlePricedMet
            );
    }

    // function addToAddressBlacklist(address user) external onlyIfModifiable onlyOwner {
    //     _addressBlacklist.push(user);
    // }

    function setConfigModifiable(bool isModifiable) external onlyIfModifiable onlyOwner {
        _isConfigModifiable = isModifiable;
    }

    function finalizeConfig() public onlyOnce {
        if (!_isFinalized) {
            return;
        }
        if (_finishTime == 0) {
            _finishTime = _finishTime + _duration;
        }
    }
}
