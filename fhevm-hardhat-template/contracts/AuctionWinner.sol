//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AuctionFactory } from "./AuctionFactory.sol";
import { ConfidentialAuction } from "./ConfidentialAuction.sol";

contract AuctionWinner is Ownable, ERC721 {
    mapping(uint256 => bool) _tokenIds;
    address private factoryAddress;
    address private assetAddress;

    constructor(address _factoryAddress) Ownable(msg.sender) ERC721("AuctionWinner", "ACT-W") {
        factoryAddress = _factoryAddress;
    }

    // TODO tokenURI
    function createWinner(address user, uint256 auctionId) public {
        ConfidentialAuction auctionOwner = AuctionFactory(factoryAddress).getAuction(auctionId);
        require(address(auctionOwner) == msg.sender, "Only auction can create bid positions.");
        require(_tokenIds[auctionId] == false, "Win already claimed.");
        _mint(user, auctionId);
        // TODO burn position nft
    }

    function setAsset(address addr) public {
        require(msg.sender == factoryAddress, 'Not factory');
        assetAddress = addr;
    }

    function burn(uint256 tokenId) external {
        require(assetAddress == msg.sender, "Caller is not a burner or owner");
        _burn(tokenId);
    }
}
