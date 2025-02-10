//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AuctionFactory } from "./AuctionFactory.sol";
import { ConfidentialAuction } from "./ConfidentialAuction.sol";

contract AuctionPosition is ERC721 {
    mapping(uint256 => uint256[]) private _tokenIds;
    mapping(uint256 => address) private _winnerAddresses;
    address factoryAddress;

    constructor(address _factoryAddress) ERC721("AuctionHouse", "ACT-P") {
        factoryAddress = _factoryAddress;
    }

    // TODO tokenURI
    function createBidPosition(address user, uint256 auctionId) public returns (uint256) {
        ConfidentialAuction auctionOwner = AuctionFactory(factoryAddress).getAuction(auctionId);
        require(address(auctionOwner) == msg.sender, "Only auction can create bid positions.");
        _tokenIds[auctionId].push();
        uint256 newItemId = _tokenIds[auctionId].length;

        _mint(user, _tokenIds[auctionId].length);

        return newItemId;
    }

    function setWinner(uint256 tokenId, address addr) public {
        require(msg.sender == factoryAddress, "Not factory");
        _winnerAddresses[tokenId] = addr;
    }

    function burn(uint256 tokenId) external {
        require(_winnerAddresses[tokenId] == msg.sender, "Caller is not a burner or owner");
        _burn(tokenId);
    }
}
