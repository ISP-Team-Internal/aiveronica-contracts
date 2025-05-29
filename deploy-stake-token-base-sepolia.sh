source .env
forge create --rpc-url base_sepolia \
    --constructor-args "0x5AFE2041B2bf3BeAf7fa4E495Ff2E9C7bd204a34" 2 "" "" \
    --private-key $PRIVATE_KEY \
    src/StakedToken.sol:stakedToken
