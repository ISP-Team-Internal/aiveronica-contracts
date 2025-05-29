#!/bin/bash

# Load environment variables
source .env

# Set default values if not provided in .env
export BASE_TOKEN_ADDRESS=${BASE_TOKEN_ADDRESS:-"0x5AFE2041B2bf3BeAf7fa4E495Ff2E9C7bd204a34"}
export MAX_WEEKS=${MAX_WEEKS:-"2"}
export TOKEN_NAME=${TOKEN_NAME:-"Staked Token"}
export TOKEN_SYMBOL=${TOKEN_SYMBOL:-"sToken"}

echo "Deploying StakedToken to Base Sepolia..."
echo "Base Token: $BASE_TOKEN_ADDRESS"
echo "Max Weeks: $MAX_WEEKS"
echo "Token Name: $TOKEN_NAME"
echo "Token Symbol: $TOKEN_SYMBOL"

# Deploy using the Forge script
forge script script/DeployStakedToken.sol:DeployStakedToken \
    --rpc-url base_sepolia \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify \
    --etherscan-api-key $BASESCAN_API_KEY

echo "Deployment completed!" 