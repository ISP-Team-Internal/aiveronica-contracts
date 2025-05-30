# StakedToken Deployment Guide

This guide explains how to deploy and initialize the StakedToken upgradeable contract.

## Overview

The StakedToken contract is an upgradeable contract that requires proper deployment using a proxy pattern and initialization instead of constructor parameters.

## Scripts Available

### 1. Complete Deployment Script
- **File**: `script/DeployStakedToken.sol`
- **Shell Script**: `deploy-staked-token-base-sepolia.sh`
- **Purpose**: Deploys both the implementation and proxy, then initializes in one go

### 2. Initialization Script
- **File**: `script/InitStakedToken.sol`
- **Shell Script**: `init-staked-token-base-sepolia.sh`
- **Purpose**: Initializes an already deployed contract

## Environment Variables

Create a `.env` file with the following variables:

```bash
# Required
PRIVATE_KEY=your_private_key_here
BASESCAN_API_KEY=your_basescan_api_key_here

# Optional (defaults provided)
BASE_TOKEN_ADDRESS=0x5AFE2041B2bf3BeAf7fa4E495Ff2E9C7bd204a34
MAX_WEEKS=2
TOKEN_NAME="Staked Token"
TOKEN_SYMBOL="sToken"

# Required only for initialization script
STAKED_TOKEN_ADDRESS=deployed_contract_address_here
```

## Usage

### Option 1: Complete Deployment (Recommended)

This deploys the implementation, proxy, and initializes in one transaction:

```bash
chmod +x deploy-staked-token-base-sepolia.sh
./deploy-staked-token-base-sepolia.sh
```

### Option 2: Separate Deployment and Initialization

If you need to deploy and initialize separately:

1. **Deploy the implementation contract only:**
```bash
forge create --rpc-url base_sepolia \
    --private-key $PRIVATE_KEY \
    src/StakedToken.sol:stakedToken
```

2. **Set the contract address in .env:**
```bash
echo "STAKED_TOKEN_ADDRESS=0x..." >> .env
```

3. **Initialize the contract:**
```bash
chmod +x init-staked-token-base-sepolia.sh
./init-staked-token-base-sepolia.sh
```

## Contract Parameters

- **baseToken**: Address of the underlying ERC20 token to be staked
- **maxWeeks**: Maximum number of weeks tokens can be locked for
- **name**: Human-readable name of the staked token
- **symbol**: Symbol/ticker of the staked token

## Important Notes

1. **Upgradeable Contract**: This contract uses OpenZeppelin's upgradeable pattern, so it needs to be deployed with a proxy.

2. **Initialization**: The contract uses `initialize()` instead of a constructor, which must be called after deployment.

3. **Access Control**: The deployer automatically gets ADMIN_ROLE and DEFAULT_ADMIN_ROLE.

4. **Verification**: The deployment script includes contract verification on Basescan.

## Troubleshooting

- If you get "contract already initialized" error, the contract has already been initialized
- If deployment fails, check your private key and RPC URL are correct
- For verification issues, ensure BASESCAN_API_KEY is set correctly 