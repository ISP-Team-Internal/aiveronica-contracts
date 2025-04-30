#!/bin/bash

# Usage: ./verify-saigon.sh <DEPOSIT_CONTRACT_ADDRESS>
# * command to verify the TestToken contract
#  forge verify-contract --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/ --chain-id 2021 0x4376b6aa3ee101098b7fdff5b92317bde4ebe045 src/TestToken.sol:TestToken
# * command to verify the DepositThresholdNFT contract
forge verify-contract --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/ --chain-id 2020 "$1" src/DepositThresholdNFT.sol:DepositThresholdNFT
