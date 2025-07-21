
# Lumina NFT Marketplace Contract

This Clarity smart contract implements a decentralized NFT marketplace for digital art on the Stacks blockchain. It supports minting, listing, buying, transferring, burning NFTs, and royalty payments.

## Features

- **Mint NFTs:** Artists can mint new NFTs with royalty information and metadata URI.
- **List NFTs:** Owners can list their NFTs for sale at a specified price.
- **Buy NFTs:** Buyers can purchase listed NFTs, with automatic royalty and marketplace fee distribution.
- **Transfer NFTs:** Owners can transfer NFTs to other principals.
- **Burn NFTs:** Owners can destroy their NFTs, removing all associated data.
- **Royalty Support:** Creators receive a percentage of each sale.
- **Marketplace Fee:** A configurable fee is taken on each sale.
- **Transfer Locks:** Temporarily lock NFT transfers for a set number of blocks.
- **Admin Controls:** Pause/unpause contract, update marketplace fee and address.
- **Read-only Getters:** Query NFT metadata, listing info, royalty info, and contract state.

## Data Structures

- **Maps**
  - `royalties`: Maps token ID to creator and royalty percent.
  - `listings`: Maps token ID to price and listing status.
  - `token-uri`: Maps token ID to metadata URI.
  - `transfer-locks`: Maps token ID to unlock block height.

- **Variables**
  - `next-id`: Next token ID to mint.
  - `contract-paused`: Paused state of the contract.
  - `marketplace-fee-percent`: Marketplace fee in basis points.
  - `marketplace-address`: Address receiving marketplace fees.

## Main Functions

### Public

- `mint-art(recipient, percent, uri)`: Mint a new NFT.
- `list-art(id, price)`: List NFT for sale.
- `buy-art(id)`: Buy a listed NFT.
- `delist-art(id)`: Remove NFT from sale.
- `update-listing-price(id, new-price)`: Change listing price.
- `set-token-uri(id, uri)`: Update NFT metadata URI.
- `transfer-art(id, recipient)`: Transfer NFT ownership.
- `burn-art(id)`: Destroy NFT and clean up data.
- `lock-transfer(id, blocks)`: Lock NFT transfer for a number of blocks.

### Admin

- `toggle-pause()`: Pause/unpause contract.
- `update-marketplace-fee(new-fee)`: Set new marketplace fee.
- `update-marketplace-address(new-address)`: Set new marketplace address.

### Read-only

- `get-token-uri(id)`: Get NFT metadata URI.
- `get-listing(id)`: Get listing info.
- `get-royalty-info(id)`: Get royalty info.
- `get-transfer-lock(id)`: Get transfer lock info.
- `get-marketplace-address()`: Get marketplace address.
- `get-marketplace-fee()`: Get marketplace fee.
- `is-contract-paused()`: Check if contract is paused.
- `get-next-token-id()`: Get next token ID to mint.

## Error Codes

- `ERR-NOT-AUTHORIZED`: Unauthorized action.
- `ERR-INVALID-PRICE`: Invalid price or value.
- `ERR-NOT-LISTED`: NFT not listed for sale.
- `ERR-ALREADY-LISTED`: NFT already listed.
- `ERR-INVALID-ADDRESS`: Invalid principal address.
- `ERR-CONTRACT-PAUSED`: Contract is paused.
- `ERR-TRANSFER-LOCKED`: NFT transfer is locked.
- `ERR-INSUFFICIENT-PAYMENT`: Payment is insufficient.
- `ERR-INVALID-PERCENTAGE`: Invalid royalty or fee percentage.

## Events

- Mint, purchase, list, delist, price update, URI update, transfer, burn, transfer lock, pause toggle, marketplace fee/address update.

## Usage

Deploy the contract to the Stacks blockchain. Interact with the public functions to mint, list, buy, transfer, and burn NFTs. Admin functions require contract owner privileges.

---

**Note:** All percentages are in basis points (1% = 100 basis points). Royalty and marketplace fee limits are enforced by the contract.
