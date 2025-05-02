// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DepositThresholdNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../src/TestToken.sol";

contract DeployDepositThresholdNFT is Script {
    function run() external {
        // Load environment variables
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address admin = vm.envAddress("ADMIN_ADDRESS");
        // uint256 startingTimestamp = block.timestamp + 1 hours; // ? Testnet: Start in 1 hour
        uint256 startingTimestamp = 1746547200; // * Mainnet: Actual start time
        uint256 campaignDuration = 14 days; // * Standard two-week campaign

        // TODO: confirm the actual values for the whitelist sale
        uint256[] memory dailyTokenAmounts = new uint256[](14);
        dailyTokenAmounts[0] = 60 * 10 ** 18; // Day 1: 1000 tokens
        dailyTokenAmounts[1] = 66 * 10 ** 18; // Day 2: 1100 tokens
        dailyTokenAmounts[2] = 73 * 10 ** 18; // Day 3: 1200 tokens
        dailyTokenAmounts[3] = 80 * 10 ** 18; // Day 4: 1300 tokens
        dailyTokenAmounts[4] = 88 * 10 ** 18; // Day 5: 1400 tokens
        dailyTokenAmounts[5] = 97 * 10 ** 18; // Day 6: 1500 tokens
        dailyTokenAmounts[6] = 106 * 10 ** 18; // Day 7: 1600 tokens
        dailyTokenAmounts[7] = 117 * 10 ** 18; // Day 8: 1700 tokens
        dailyTokenAmounts[8] = 129 * 10 ** 18; // Day 9: 2000 tokens
        dailyTokenAmounts[9] = 141 * 10 ** 18; // Day 10: 2200 tokens
        dailyTokenAmounts[10] = 156 * 10 ** 18; // Day 11: 2400 tokens
        dailyTokenAmounts[11] = 171 * 10 ** 18; // Day 12: 2600 tokens
        dailyTokenAmounts[12] = 188 * 10 ** 18; // Day 13: 2800 tokens
        dailyTokenAmounts[13] = 207 * 10 ** 18; // Day 14: 3000 tokens

        // Set up daily whitelist limits (can be different for each day)
        // TODO: confirm the actual values for the whitelist sale
        uint256[] memory dailyWhitelistLimits = new uint256[](14);
        dailyWhitelistLimits[0] = 1000;
        dailyWhitelistLimits[1] = 2000;
        for (uint256 i = 2; i < 14; i++) {
            dailyWhitelistLimits[i] = 5000; // Using same limit as before, but could be different per day
        }

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        // Deploy the TestToken contracts
        address tokenAddress = vm.envAddress("PIXEL_TOKEN_ADDRESS");
        IERC20 token;
        if (tokenAddress == address(0)) {
            token = new TestToken(admin, "Pixel", "PIX");
            console.log("Test token deployed at:", address(token));
        } else {
            token = IERC20(tokenAddress);
            console.log("Test token already deployed at:", tokenAddress);
        }

        // Deploy the DepositThresholdNFT with the new parameters
        DepositThresholdNFT depositNFT = new DepositThresholdNFT(
            startingTimestamp,
            address(token),
            dailyTokenAmounts,
            dailyWhitelistLimits,
            campaignDuration,
            admin,
            "https://aiveronica-website.vercel.app/AIV_Key_BG_03_3000x3000.png" // * Testnet
            // "https://aiveronica.ai/AIV_Key_BG_03_3000x3000.png" // * Mainnet
        );
        console.log("DepositThresholdNFT deployed at:", address(depositNFT));

        // Stop broadcasting
        vm.stopBroadcast();
    }
}
