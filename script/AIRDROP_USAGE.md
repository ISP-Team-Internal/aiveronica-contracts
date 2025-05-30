# AIV Token Airdrop Script Usage Guide

This guide explains how to use the AIV token airdrop script with multiple distribution methods.

## Setup

1. **Update foundry.toml** (already done):
   - Added `fs_permissions = [{ access = "read", path = "./" }]` to allow CSV file reading

2. **Set your environment variables** in `.env`:
   ```bash
   PRIVATE_KEY=your_private_key_here
   ```

## Distribution Methods

The script supports 3 methods in order of priority:

### Method 1: CSV File (Recommended for large lists)

1. **Create a CSV file** named `airdrop_distribution.csv`:
   ```csv
   address,amount
   0x742E8D0aed6E21e2f8dABf7C8D9b3d96aF61F5a4,1000000000000000000000
   0x1234567890123456789012345678901234567890,500000000000000000000
   ```

2. **Use the Python helper** (optional):
   ```bash
   python generate_airdrop_csv.py
   ```

3. **Run the airdrop**:
   ```bash
   # Auto mode (tries CSV first)
   forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast

   # Force CSV mode
   DISTRIBUTION_METHOD=csv forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast
   ```

### Method 2: Environment Variables (Recommended for medium lists)

1. **Set environment variables**:
   ```bash
   export AIRDROP_RECIPIENTS="0x742E8D0aed6E21e2f8dABf7C8D9b3d96aF61F5a4,0x1234567890123456789012345678901234567890"
   export AIRDROP_AMOUNTS="1000000000000000000000,500000000000000000000"
   ```

2. **Run the airdrop**:
   ```bash
   # Force environment variable mode
   DISTRIBUTION_METHOD=env forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast
   ```

### Method 3: Hardcoded (Recommended for small lists)

1. **Edit the script** directly in `getHardcodedDistribution()` function
2. **Run the airdrop**:
   ```bash
   # Force hardcoded mode
   DISTRIBUTION_METHOD=hardcoded forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast
   ```

## Environment Variables

| Variable | Description | Default | Example |
|----------|-------------|---------|---------|
| `PRIVATE_KEY` | Your wallet private key | Required | `0x123...` |
| `DISTRIBUTION_METHOD` | Distribution method | `auto` | `csv`, `env`, `hardcoded`, `auto` |
| `AIRDROP_RECIPIENTS` | Comma-separated addresses | - | `0x123...,0x456...` |
| `AIRDROP_AMOUNTS` | Comma-separated amounts in wei | - | `1000000000000000000000,500000000000000000000` |

## Auto Mode (Default)

When `DISTRIBUTION_METHOD=auto` (or not set), the script tries methods in this order:
1. CSV file (`./airdrop_distribution.csv`)
2. Environment variables (`AIRDROP_RECIPIENTS` + `AIRDROP_AMOUNTS`)
3. Hardcoded distribution (fallback)

## Amount Format

All amounts should be in **wei** (smallest unit):
- 1 AIV = 1,000,000,000,000,000,000 wei (assuming 18 decimals)
- Use the Python script to convert from AIV to wei easily

## Security Notes

1. **Never commit your private key** to version control
2. **Test on testnet first** before mainnet deployment
3. **Verify recipient addresses** before running large airdrops
4. **Check your AIV balance** - the script will verify but always double-check

## Example Commands

```bash
# Test with dry run (no --broadcast)
forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet

# Run actual airdrop
forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast --verify

# Force specific method
DISTRIBUTION_METHOD=csv forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast

# Use environment variables
AIRDROP_RECIPIENTS="0x742E8D0aed6E21e2f8dABf7C8D9b3d96aF61F5a4" AIRDROP_AMOUNTS="1000000000000000000000" forge script script/AirdropAIV.s.sol:AirdropAIV --rpc-url base_mainnet --broadcast
```

## Troubleshooting

### CSV File Issues
- Ensure the file is named exactly `airdrop_distribution.csv`
- Check that `fs_permissions` is set in `foundry.toml`
- Verify CSV format (address,amount with proper headers)

### Environment Variable Issues
- Check variable names exactly match: `AIRDROP_RECIPIENTS`, `AIRDROP_AMOUNTS`
- Ensure no spaces around commas in the lists
- Verify addresses are properly checksummed

### Transaction Issues
- Verify you have enough AIV tokens
- Check gas fees on Base mainnet
- Ensure recipient addresses are valid

## Gas Optimization

For large airdrops (>100 recipients), consider:
1. **Batching**: Split into multiple smaller transactions
2. **Gas price**: Monitor Base network congestion
3. **Timing**: Run during low-traffic periods 