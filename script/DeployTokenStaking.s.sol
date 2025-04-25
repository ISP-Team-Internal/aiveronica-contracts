// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {TokenStaking} from "../src/TokenStaking.sol";
import {TestToken} from "../src/TestToken.sol"; // Mock token
import "forge-std/console.sol";
contract DeployTokenStaking is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy mock VADER token
        TestToken testToken;
        address tokenAddress = vm.envAddress("PIXEL_TOKEN_ADDRESS");
        if (tokenAddress == address(0)) {
            testToken = new TestToken(msg.sender, "PIXEL", "PIX");
            console.log("Test token deployed at:", address(testToken));
        } else {
            testToken = TestToken(tokenAddress);
            console.log("Test token already deployed at:", tokenAddress);
        }

        // Define staking periods (e.g., 30, 60, 90 days in seconds)
        uint256[] memory periods = new uint256[](4);
        periods[0] = 30 days;
        periods[1] = 60 days;
        periods[2] = 90 days;
        periods[3] = 180 days;

        // Deploy staking contract
        TokenStaking stakingContract = new TokenStaking(address(testToken), periods);

        console.log("TokenStaking deployed at:", address(stakingContract));

        vm.stopBroadcast();
    }
}