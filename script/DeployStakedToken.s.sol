// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {stakedToken} from "../src/StakedToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/console.sol";

contract DeployStakedToken is Script {
    function run() external {
        vm.startBroadcast();

        // Get initialization parameters from environment variables or use defaults
        address baseToken = vm.envOr("BASE_TOKEN_ADDRESS", address(0x5AFE2041B2bf3BeAf7fa4E495Ff2E9C7bd204a34));
        uint8 maxWeeks = uint8(vm.envOr("MAX_WEEKS", uint256(2)));
        string memory tokenName = vm.envOr("TOKEN_NAME", string("Staked Token"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("sToken"));

        console.log("Deploying StakedToken...");
        console.log("Base Token:", baseToken);
        console.log("Max Weeks:", maxWeeks);
        console.log("Token Name:", tokenName);
        console.log("Token Symbol:", tokenSymbol);

        // Deploy the implementation contract
        stakedToken implementation = new stakedToken();
        console.log("Implementation deployed at:", address(implementation));

        // Encode the initialization call
        bytes memory data = abi.encodeWithSelector(
            stakedToken.initialize.selector,
            baseToken,
            maxWeeks,
            tokenName,
            tokenSymbol
        );

        // Deploy the proxy and initialize in one transaction
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), data);
        console.log("Proxy deployed at:", address(proxy));

        // Cast to stakedToken for easier interaction
        stakedToken stakedTokenProxy = stakedToken(address(proxy));
        console.log("StakedToken deployed and initialized successfully!");
        console.log("Final contract address:", address(stakedTokenProxy));

        vm.stopBroadcast();
    }
} 