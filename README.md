# confidential-auction

Confidential Single-Price Auction for Tokens with Sealed Bids using Zama's fhEVM

## How it works

The project consists of two parts the auction smart contracts and frontend interface to interact with auctions.

### The smart contacts architecture

- `AuctionFactory.sol` to create confidential auctions
- `ConfidentialAuction.sol` through which users can bid on auctions confidentially
- `AuctionConfig.sol` the auction config that the auction owner can edit
- `AuctionPosition.sol` an NFT that represents a bidding position on an auction
- `AuctionWinner.sol` an NFT that represents a winning bid on an auction
- `Asset.sol` a contract that represents an asset that is being auction of. This can be any any asset that has a `_mint` function, which is called by it.

### Confidential Bid

A confidential bids represents a bid position on an auction. When a user bids it sends over the encrypted bid parameters i.e. amount and token price. Furthermore a lock amount is sent to commit to the bid. A position NFT gets minted in his name.  
If a bid reaches the settle price the auction is finished. To calculate this we add up the encrypted amounts and check against an ecnrypted settle price.  
Furthermore if the finish time the auction is also finished.  
A finished auction triggers a bid winners calculation method, which decrypts the bids, orders them and distributes winning NFTs to the winning bid's owners.  
The asset's has a `claimWin` method which burns the user's winning NFT and mints an asset to the user.  
The winning and position NFTs are tradeable between users, which could add more functionalities e.g. users could buy out an auction, improve their position, etc.  
Also this architecture allows the user to wrap any asset that she likes, which can be a standard e.g. ERC20 or a custom one.

### Type of assets that you can action include:

- ERC20 e.g. ICO coin launch
- ERC721 launch mint rights
- ERC1155 as a token launch and rights to mint as an NFT
- ERC4626, auction token vaults
- Custom assets e.g. RWAs, ads, ENS domains, etc., that will implement the ICustomAsset interface
  <!-- Ad auction: https://www.kevel.com/blog/ad-auctions -->
  <!-- bidspirit: https://www.bidspirit-themes.com/#features -->
  <!-- Protected Auction Services: https://github.com/privacysandbox/protected-auction-services-docs/blob/main/bidding_auction_services_system_design.md -->

<!-- ## True confidentiallity

To make the auction truly confidential the EIP4337 standard was integrated into the workflow.
Participants can claim  -->

<!-- Permit2 signed and hashed, can be redeemed w/ a successfull auction win (ZK) -->
