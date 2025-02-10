//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AuctionFactory } from "./AuctionFactory.sol";
import { ConfidentialAuction } from "./ConfidentialAuction.sol";

contract AuctionPosition is ERC721 {
    mapping(uint256 => uint256) _tokenIds;
    address factoryAddress;
    address winnerAddress;

    constructor(address _factoryAddress) ERC721("AuctionHouse", "ACT-P") {
        factoryAddress = _factoryAddress;
    }

    // TODO tokenURI
    function createBidPosition(address user, uint256 auctionId) public returns (uint256) {
        ConfidentialAuction auctionOwner = AuctionFactory(factoryAddress).getAuction(auctionId);
        require(address(auctionOwner) == msg.sender, "Only auction can create bid positions.");
        uint256 newItemId = _tokenIds[auctionId]++;
        _mint(user, newItemId);

        return newItemId;
    }

    function setWinner(address addr) public {
        require(msg.sender == factoryAddress, "Not factory");
        winnerAddress = addr;
    }

    function burn(uint256 tokenId) external {
        require(winnerAddress == msg.sender, "Caller is not a burner or owner");
        _burn(tokenId);
    }
}
