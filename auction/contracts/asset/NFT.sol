//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AuctionWinner } from "../AuctionWinner.sol";
import { ConfidentialAuction } from "../ConfidentialAuction.sol";

contract NFT is ERC721 {
    AuctionWinner winnerNFT;
    ConfidentialAuction auction;

    constructor(string memory name, string memory symbol, address _winner, address _auction) ERC721(name, symbol) {
        winnerNFT = AuctionWinner(_winner);
        auction = ConfidentialAuction(_auction);
    }

    function claimWin(uint256 tokenId) payable public {
        // Get bid
        ConfidentialAuction.DecryptedBid memory bid = auction.getDecryptedBid(tokenId);

        // Pay the amount
        uint256 total = bid.amount * bid.pricePer;
        require(msg.value > total, "Not enough msg.value");

        // Burn winner NFT
        winnerNFT.burn(tokenId);
        _mint(msg.sender, bid.amount);
    }
}
