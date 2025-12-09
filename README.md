# 🏗️ RWA Builder

> A proof-of-concept for building Real World Asset (RWA) tokenization contracts using Chainlink Functions and Data Feeds

[![Demo](https://img.shields.io/badge/demo-live-success)](https://rwa.cladjules.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**⚠️ Important:** This project is a proof-of-concept. Smart contracts are not optimized for gas efficiency and have not been audited. **Use at your own risk.**

## 🌐 Live Demo

Check out the live demo: **[rwa.cladjules.com](https://rwa.cladjules.com/)**

---

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [How It Works](#-how-it-works)
- [Prerequisites](#-prerequisites)
- [Environment Setup](#-environment-setup)
- [Installation](#-installation)
- [Deployment](#-deployment)
- [Development](#-development)
- [Tech Stack](#-tech-stack)

---

## 🏛️ Architecture Overview

This project implements a tokenization system for Real World Assets using ERC1155 tokens, combining on-chain and off-chain components:

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER INTERACTION                         │
│                    (Mint/Transfer/Withdraw)                      │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      TokenAsset Contract                         │
│                        (ERC1155 + ERC2981)                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Asset Logic  │  │ Price Oracle │  │ Chainlink Functions  │  │
│  │  - Mint      │  │ (ETH/USD)    │  │  - Update External   │  │
│  │  - Transfer  │  │ Data Feed    │  │    Database          │  │
│  │  - Withdraw  │  │              │  │  - Verify Actions    │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└────┬────────────────────┬────────────────────┬───────────────────┘
     │                    │                    │
     │                    │                    │
     ▼                    ▼                    ▼
┌─────────┐       ┌──────────────┐    ┌────────────────────────┐
│ Base    │       │  Chainlink   │    │  Chainlink Functions   │
│ Sepolia │       │  Price Feed  │    │  DON (Decentralized    │
│ Network │       │  (ETH/USD)   │    │  Oracle Network)       │
└─────────┘       └──────────────┘    └──────────┬─────────────┘
                                                  │
                                                  │ HTTP Request
                                                  ▼
                                      ┌────────────────────────┐
                                      │   External API         │
                                      │   (Your Backend)       │
                                      │  - Validates actions   │
                                      │  - Updates DB          │
                                      │  - Uses Gist Secret    │
                                      └────────────────────────┘
```

### Key Components:

1. **TokenAsset Contract**: ERC1155 multi-token contract with integrated Chainlink oracles
2. **Chainlink Price Feeds**: Real-time ETH/USD pricing for asset valuation
3. **Chainlink Functions**: Decentralized serverless functions to interact with external APIs
4. **External API**: Your backend service that handles off-chain business logic
5. **Encrypted Secrets**: Securely stored API credentials using Chainlink DON

---

## ⚙️ How It Works

### Minting Flow

1. User calls `mint()` with token ID, quantity, and payment in ETH
2. Contract checks ETH/USD price from Chainlink Data Feed
3. Contract validates payment amount matches asset price
4. Tokens are minted to user's address
5. Chainlink Function calls external API to update off-chain database

### Update Flow (via Chainlink Functions)

1. Contract triggers Chainlink Function with action details
2. Function retrieves encrypted API secret from DON
3. Function makes HTTP request to your backend API
4. Backend validates request and updates database
5. Function returns success/failure to contract
6. Contract emits event with result

### Secret Management

- API credentials encrypted locally using `create-secrets` script
- **Encrypted** secrets stored in GitHub Gist (never in plaintext)
- DON fetches the encrypted secrets from Gist URL via `upload-secrets` script
- Encrypted secrets uploaded to and stored in Chainlink DON
- Secrets decrypted only during function execution within the DON's secure environment
- Secrets never exposed on-chain, in client code, or in plaintext anywhere in the process

---

## 📦 Prerequisites

Before you begin, ensure you have:

- **Node.js** v18+ and **npm** or **yarn**
- **Hardhat** 3.x
- An **Alchemy** account ([sign up here](https://alchemy.com))
- A **Chainlink Functions** subscription ([create here](https://functions.chain.link/base-sepolia))
- A **Base Sepolia** testnet wallet with ETH ([faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet))
- A **GitHub account** for creating secret Gists ([sign up here](https://github.com))

---

## 🔐 Environment Setup

### 1. Create `.env` file

Create a `.env` file in the project root:

```bash
# Alchemy API Key (get from https://alchemy.com)
ALCHEMY_API_KEY=your_alchemy_api_key_here

# Private key of your deployment wallet (Base Sepolia testnet)
# ⚠️ NEVER commit this or use a wallet with real funds!
TESTNET_PRIVATE_KEY=0x_your_private_key_here

# BaseScan API Key for contract verification (get from https://basescan.org/apis)
EXPLORER_API_KEY=your_basescan_api_key_here

# Chainlink Functions Subscription ID (create at https://functions.chain.link/base-sepolia)
FN_SUB_ID=123

# Your API secret key that will be encrypted and stored in Chainlink DON
# This will be accessible in your Chainlink Function via secrets.apiSecret
CONTRACT_FN_API_SECRET=your_api_secret_key_here

# Your external REST API endpoint (webhook) that Chainlink Functions will call
# Currently supports a simple GET request with query parameters
# Available variables to use in the URL: id, quantity, to, hash
# The secret is passed as: secret=${secrets.apiSecret}
# Example: https://your-api.com/webhook?secret=${secrets.apiSecret}&id=${id}&quantity=${quantity}
CONTRACT_FN_UPDATE_API_URL=https://your-api.com/api/update?secret=

# GitHub Gist URL containing your encrypted secrets (raw URL to .secrets-create.json)
GIST_URL=https://gist.githubusercontent.com/your-username/gist-id/raw/secrets.json
```

### 2. Create and Upload Secrets

Secrets are now managed in two steps:

**Step 2a: Create encrypted secrets locally**

Run the create-secrets script to encrypt your API secret:

```bash
npm run create-secrets
```

This creates a `.secrets-create.json` file locally with your encrypted secret.

**Step 2b: Upload encrypted secrets to GitHub Gist**

Create a **secret** Gist at [gist.github.com](https://gist.github.com):

1. Upload the `.secrets-create.json` file content (already encrypted) to a new Gist
2. Make it **secret** (not public) for additional privacy
3. Get the **raw URL** and set it as `GIST_URL` in your `.env`

⚠️ **Note:** The secrets are already encrypted in the `.secrets-create.json` file, so they're safe to upload to Gist.

**Example Gist URL:**

```
https://gist.githubusercontent.com/username/abc123def456/raw/.secrets-create.json
```

⚠️ **Important:** Make sure the Gist URL includes `/raw/` to get the raw file content.

### 3. Fund Your Chainlink Subscription

1. Visit [functions.chain.link/base-sepolia](https://functions.chain.link/base-sepolia)
2. Create a new subscription
3. Fund it with LINK tokens (get from [faucet](https://faucets.chain.link/base-sepolia))
4. Copy the subscription ID to `FN_SUB_ID` in `.env`

---

## 🚀 Installation

```bash
# Clone the repository
git clone https://github.com/cladjules/rwa-builder.git
cd rwa-builder

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your values
nano .env
```

---

## 📤 Deployment

### Step 1: Create Encrypted Secrets

```bash
npm run create-secrets
```

This encrypts your `CONTRACT_FN_API_SECRET` and saves it to `.secrets-create.json`.

### Step 2: Upload Secrets File to GitHub Gist

Upload the `.secrets-create.json` content to a secret Gist (see [Environment Setup](#2-create-and-upload-secrets)) and set the raw URL in your `.env` as `GIST_URL`.

### Step 3: Upload Secrets to Chainlink DON

```bash
npm run upload-secrets:baseSepolia
```

This retrieves your encrypted secrets from the Gist URL and uploads them to the Chainlink Decentralized Oracle Network. The result is saved to `.secrets-upload-result.txt`.

### Step 4: Deploy Contracts

```bash
npm run deploy:baseSepolia
```

This will:

- Deploy the `TokenAsset` contract to Base Sepolia
- Deploy 10 sample RWA tokens with different prices
- Verify the contract on BaseScan
- Save deployment info to `ignition/deployments/chain-84532/`

### Step 5: Add Consumer to Chainlink Subscription

After deployment, add your contract address as a consumer:

1. Go to [functions.chain.link/base-sepolia](https://functions.chain.link/base-sepolia)
2. Open your subscription
3. Click "Add Consumer"
4. Paste your deployed contract address (found in `ignition/deployments/chain-84532/deployed_addresses.json`)

---

## 🛠️ Development

### Run Tests

```bash
npm test
```

Tests are written using Hardhat and can be found in the `test/` directory.

### Project Structure

```
rwa-builder/
├── contracts/
│   ├── TokenAsset.sol           # Main ERC1155 RWA contract
│   ├── TokenAsset.t.sol         # Foundry-style tests
│   ├── interfaces/
│   │   └── ITokenAsset.sol      # Contract interface
│   └── mocks/
│       ├── MockFunctionsRouter.sol   # Mock for testing
│       └── MockV3Aggregator.sol      # Mock price feed
├── ignition/
│   └── modules/
│       └── TokenAsset.ts        # Deployment script with Chainlink Function code
├── scripts/
│   ├── create-secrets.ts        # Create encrypted secrets locally
│   ├── upload-secrets.ts        # Upload encrypted secrets to DON
│   ├── utils.ts                 # Shared utility functions
│   └── send-op-tx.ts           # Additional utilities
├── test/
│   └── TokenAsset.ts           # Test suite
├── hardhat.config.ts           # Hardhat configuration
├── .env                        # Environment variables (create this!)
├── .secrets-create.json        # Generated encrypted secrets (git-ignored)
└── .secrets-upload-result.txt  # DON upload result (git-ignored)
```

### Supported Networks

Currently, only **Base Sepolia** testnet is configured. To add more networks, update:

- `hardhat.config.ts` - Add network configuration
- `ignition/modules/TokenAsset.ts` - Add DON IDs and price feed addresses
- `scripts/upload-secrets.ts` - Add network-specific settings

---

## 🧰 Tech Stack

- **Smart Contracts**: Solidity ^0.8.28
- **Token Standards**: ERC1155 (Multi-Token), ERC2981 (Royalties)
- **Development Framework**: Hardhat 3.x
- **Testing**: Hardhat + Foundry-style tests
- **Oracles**:
  - Chainlink Functions (Serverless compute)
  - Chainlink Price Feeds (ETH/USD)
- **Provider**: Alchemy
- **Network**: Base Sepolia (Testnet)
- **Libraries**:
  - OpenZeppelin Contracts
  - Chainlink Functions Toolkit
  - ethers.js v6

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/cladjules/rwa-builder/issues).

---

## ⚠️ Disclaimer

This is a proof-of-concept project for educational and demonstration purposes. The smart contracts have not been audited and are not production-ready. Do not use with real assets or on mainnet without proper security audits and testing.

---

**Built with ❤️ using Chainlink and Base**
