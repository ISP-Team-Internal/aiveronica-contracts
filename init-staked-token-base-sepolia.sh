#!/bin/bash

# Load environment variables
source .env

# Check if STAKED_TOKEN_ADDRESS is set
if [ -z "$STAKED_TOKEN_ADDRESS" ]; then
    echo "Error: STAKED_TOKEN_ADDRESS not set in .env file"
    echo "Please set STAKED_TOKEN_ADDRESS to the deployed contract address"
    exit 1
fi

# Set default values if not provided in .env
export BASE_TOKEN_ADDRESS=${BASE_TOKEN_ADDRESS:-"0x5AFE2041B2bf3BeAf7fa4E495Ff2E9C7bd204a34"}
export MAX_WEEKS=${MAX_WEEKS:-"2"}
export TOKEN_NAME=${TOKEN_NAME:-"Staked Token"}
export TOKEN_SYMBOL=${TOKEN_SYMBOL:-"sToken"}

echo "Initializing StakedToken on Base Sepolia..."
echo "Contract Address: $STAKED_TOKEN_ADDRESS"
echo "Base Token: $BASE_TOKEN_ADDRESS"
echo "Max Weeks: $MAX_WEEKS"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"

# Initialize using the Forge script
forge script script/InitStakedToken.sol:InitStakedToken \
    --rpc-url base_sepolia \
    --private-key $PRIVATE_KEY \
    --broadcast

echo "Initialization completed!" 