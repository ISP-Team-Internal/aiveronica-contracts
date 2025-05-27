# Usage: ./verify-base-sepolia.sh <STAKING_CONTRACT_ADDRESS> <TOKEN_ADDRESS>
source .env
forge verify-contract "$2" src/TestToken.sol:TestToken --chain 84532 --constructor-args $(cast abi-encode "constructor(address,string,string)" $ADMIN_ADDRESS "Sample Token" "SPT") --watch
forge verify-contract "$1" src/TokenStaking.sol:TokenStaking --chain 84532 --watch --constructor-args $(cast abi-encode "constructor(address,uint256[])" $2 "[2592000,5184000,7776000,15552000]")