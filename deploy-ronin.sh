source .env
forge script script/DeployDepositThresholdNFT.s.sol --rpc-url ronin_mainnet --private-key $PRIVATE_KEY --broadcast --priority-gas-price 20gwei --with-gas-price 21gwei --verifier sourcify --verifier-url https://sourcify.roninchain.com/server/
