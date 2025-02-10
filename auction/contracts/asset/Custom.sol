//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { AuctionWinner } from "../AuctionWinner.sol";
import { ConfidentialAuction } from "../ConfidentialAuction.sol";

contract Custom {
    address asset;
    AuctionWinner winnerNFT;
    ConfidentialAuction auction;

    constructor(address _winner, address _auction, address myAsset) {
        asset = myAsset;
        winnerNFT = AuctionWinner(_winner);
        auction = ConfidentialAuction(_auction);
    }

    function claimWin(uint256 tokenId) public payable {
        // Get bid
        ConfidentialAuction.DecryptedBid memory bid = auction.getDecryptedBid(tokenId);

        // Pay the amount
        uint256 total = bid.amount * bid.pricePer;
        require(msg.value > total, "Not enough msg.value");

        // Burn winner NFT
        winnerNFT.burn(tokenId);
        bytes memory data = abi.encodeWithSignature("_mint(uint256)", bid.amount);

        // Call the target contract
        (bool success, bytes memory result) = asset.call(data);

        require(success, "Failed to mint");
    }
}
