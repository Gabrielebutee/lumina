
# Lumina NFT Marketplace Contract

This enhanced Clarity smart contract implements a decentralized NFT marketplace for digital art on the Stacks blockchain, featuring dynamic royalties, auctions, and advanced trading capabilities.

## Features

### Core Features
- **Mint NFTs:** Artists can mint new NFTs with royalty information and metadata URI.
- **List NFTs:** Owners can list their NFTs for sale at a specified price.
- **Buy NFTs:** Buyers can purchase listed NFTs, with automatic fee distribution.
- **Transfer NFTs:** Owners can transfer NFTs to other principals.
- **Burn NFTs:** Owners can destroy their NFTs, removing all associated data.

### Dynamic Royalty System
- **Split Royalties:** Support for up to 10 creators with different percentage shares.
- **Decaying Royalties:** Royalty percentages that decrease over time.
- **Flexible Payments:** Automatic distribution of royalties to multiple creators.

### Auction System
- **Create Auctions:** Set start price, reserve price, and duration.
- **Bidding:** Place bids with automatic refunds to previous highest bidder.
- **Anti-sniping:** Automatic extension when bids are placed near auction end.
- **Settlement:** Automatic distribution of funds and NFT transfer on auction end.
- **Bid Tracking:** Event-based system for tracking bid history.

### Security & Control
- **Transfer Locks:** Temporarily lock NFT transfers.
- **Admin Controls:** Pause/unpause contract, update fees and settings.
- **Marketplace Fee:** Configurable fee structure.
- **Auction Settings:** Adjustable duration limits and extension periods.

## Data Structures

### Core Maps
- `lumina-royalties`: Maps token ID to creator and royalty percent.
- `lumina-listings`: Maps token ID to price and listing status.
- `lumina-token-uri`: Maps token ID to metadata URI.
- `lumina-transfer-locks`: Maps token ID to unlock block height.

### Dynamic Royalty Maps
- `lumina-creator-splits`: Maps token ID to list of creators and their percentages.
- `lumina-royalty-decay`: Maps token ID to initial percent, decay rate, and mint block.

### Auction Maps
- `lumina-auctions`: Maps token ID to auction details (seller, prices, bidder, end time).
- `lumina-bid-count`: Maps token ID to number of bids.
- `lumina-latest-bid`: Maps token ID to latest bid information.

### Variables
#### Core Variables
- `lumina-next-id`: Next token ID to mint.
- `lumina-contract-paused`: Paused state of the contract.
- `lumina-marketplace-fee-percent`: Marketplace fee in basis points.
- `lumina-marketplace-address`: Address receiving marketplace fees.

#### Auction Variables
- `lumina-min-auction-duration`: Minimum auction duration (~1 day).
- `lumina-max-auction-duration`: Maximum auction duration (~1 week).
- `lumina-auction-extension-blocks`: Anti-sniping extension period (~12 hours).

## Functions

### Core Public Functions
- `mint-lumina-art(recipient, percent, uri)`: Mint a new NFT.
- `list-lumina-art(id, price)`: List NFT for sale.
- `buy-lumina-art(id)`: Buy a listed NFT.
- `delist-lumina-art(id)`: Remove NFT from sale.
- `update-lumina-listing-price(id, new-price)`: Change listing price.
- `set-lumina-token-uri(id, uri)`: Update NFT metadata URI.
- `transfer-lumina-art(id, recipient)`: Transfer NFT ownership.
- `burn-lumina-art(id)`: Destroy NFT and clean up data.
- `lock-lumina-transfer(id, blocks)`: Lock NFT transfer.

### Dynamic Royalty Functions
- `set-lumina-creator-splits(id, creators)`: Set multiple creator royalties.
- `set-lumina-royalty-decay(id, initial-percent, decay-rate)`: Set decaying royalties.

### Auction Functions
- `create-lumina-auction(id, start-price, reserve-price, duration)`: Start auction.
- `place-lumina-bid(id, bid-amount)`: Place bid on auction.
- `settle-lumina-auction(id)`: Conclude auction and distribute funds.
- `cancel-lumina-auction(id)`: Cancel auction (if no bids).

### Admin Functions
- `toggle-lumina-pause()`: Pause/unpause contract.
- `update-lumina-marketplace-fee(new-fee)`: Set marketplace fee.
- `update-lumina-marketplace-address(new-address)`: Set marketplace address.
- `update-lumina-auction-settings(min, max, extension)`: Configure auction parameters.

### Read-only Functions
#### Core Queries
- `get-lumina-token-uri(id)`: Get NFT metadata URI.
- `get-lumina-listing(id)`: Get listing info.
- `get-lumina-royalty-info(id)`: Get royalty info.
- `get-lumina-transfer-lock(id)`: Get transfer lock info.
- `get-lumina-marketplace-address()`: Get marketplace address.
- `get-lumina-marketplace-fee()`: Get marketplace fee.
- `is-lumina-contract-paused()`: Check contract pause state.
- `get-lumina-next-token-id()`: Get next token ID.

#### Dynamic Royalty Queries
- `get-lumina-creator-splits(id)`: Get creator share distribution.
- `get-lumina-royalty-decay(id)`: Get royalty decay settings.
- `get-lumina-current-royalty(id)`: Get current royalty rate.

#### Auction Queries
- `get-lumina-auction(id)`: Get auction details.
- `get-lumina-bid-count(id)`: Get number of bids.
- `get-lumina-latest-bid(id)`: Get latest bid info.
- `lumina-is-auction-active(id)`: Check if auction is active.
- `get-lumina-auction-settings()`: Get auction configuration.
- `get-lumina-auction-time-left(id)`: Get remaining auction time.

## Error Codes

### Core Errors
- `ERR-LUMINA-NOT-AUTHORIZED`: Unauthorized action.
- `ERR-LUMINA-INVALID-PRICE`: Invalid price or value.
- `ERR-LUMINA-NOT-LISTED`: NFT not listed for sale.
- `ERR-LUMINA-ALREADY-LISTED`: NFT already listed.
- `ERR-LUMINA-INVALID-ADDRESS`: Invalid principal address.
- `ERR-LUMINA-CONTRACT-PAUSED`: Contract is paused.
- `ERR-LUMINA-TRANSFER-LOCKED`: NFT transfer is locked.
- `ERR-LUMINA-INSUFFICIENT-PAYMENT`: Payment is insufficient.
- `ERR-LUMINA-INVALID-PERCENTAGE`: Invalid royalty or fee percentage.

### Auction Errors
- `ERR-LUMINA-AUCTION-ACTIVE`: Auction is currently active.
- `ERR-LUMINA-AUCTION-ENDED`: Auction has ended.
- `ERR-LUMINA-BID-TOO-LOW`: Bid amount is too low.
- `ERR-LUMINA-AUCTION-NOT-FOUND`: Auction doesn't exist.
- `ERR-LUMINA-INVALID-DURATION`: Invalid auction duration.
- `ERR-LUMINA-RESERVE-NOT-MET`: Reserve price not met.

## Events

### Core Events
- Mint, purchase, list, delist, price update, URI update
- Transfer, burn, transfer lock
- Contract pause toggle, fee updates

### Royalty Events
- Creator splits updates
- Royalty decay settings
- Royalty distributions

### Auction Events
- Auction creation and cancellation
- Bid placement and history
- Auction settlement and results
- Reserve price status

## Constants

- `LUMINA-MAX-ROYALTY-PERCENTAGE`: 25% (2500 basis points)
- `LUMINA-MAX-MARKETPLACE-FEE`: 10% (1000 basis points)
- `LUMINA-MAX-CREATORS`: 10 creators per NFT
- Auction durations: 1 day minimum, 2 weeks maximum
- Anti-sniping extension: up to 1 day

## Usage

1. Deploy the contract to the Stacks blockchain
2. Use public functions to:
   - Mint and manage NFTs
   - Create fixed-price listings
   - Set up auctions with reserve prices
   - Configure dynamic royalties
   - Place bids and participate in auctions
3. Admin functions require contract owner privileges for:
   - Contract pause control
   - Fee management
   - Auction parameter configuration

---

**Notes:** 
- All percentages are in basis points (1% = 100 basis points)
- Royalty and marketplace fee limits are enforced by the contract
- Auction durations and extensions are measured in blocks
- Creator splits must total 100% (10000 basis points)
