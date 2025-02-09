//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./ConfidentialAuction.sol";
import { AuctionPosition } from "./AuctionPosition.sol";
import { AuctionWinner } from "./AuctionWinner.sol";
import { NFT } from "./asset/NFT.sol";

enum AssetType {
    ERC20,
    ERC721,
    ERC1155,
    ERC4626,
    CUSTOM
}

contract AuctionFactory {
    ConfidentialAuction[] private _auctions;
    event AuctionCreated(address indexed auctionAddress, string indexed name, AssetType assetType);
    AuctionPosition position;
    AuctionWinner winner;

    // TODO Config preset, expiration time
    function createAuction(
        string memory name,
        AssetType assetType,
        uint256 settlePrice,
        address assetAddress
    ) public returns (address) {
        position = new AuctionPosition(address(this));
        winner = new AuctionWinner(address(this));
        if (assetAddress == address(0)) {
            if (assetType == AssetType.ERC721) {
                assetAddress = address(new NFT(name, name, address(position), address(winner)));
            }
        } 
        position.setWinner(address(winner));
        winner.setAsset(assetAddress);
        ConfidentialAuction auction = new ConfidentialAuction(_auctions.length, name, assetType, settlePrice);
        _auctions.push(auction);
        emit AuctionCreated(address(auction), name, assetType);
        return address(auction);
    }

    function getAuction(uint256 id) public view returns (ConfidentialAuction) {
        return _auctions[id];
    }

    function getPositionNFT() public view returns (AuctionPosition) {
        return position;
    }

    function getWinnerNFT() public view returns (AuctionWinner) {
        return winner;
    }
}
