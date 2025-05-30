// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {stakedToken} from "../src/StakedToken.sol";
import "forge-std/console.sol";

contract InitStakedToken is Script {
    function run() external {
        vm.startBroadcast();

        // Get the deployed contract address from environment variable
        address stakedTokenAddress = vm.envAddress("STAKED_TOKEN_ADDRESS");
        require(stakedTokenAddress != address(0), "STAKED_TOKEN_ADDRESS not set");

        // Get initialization parameters from environment variables or use defaults
        address baseToken = vm.envOr("BASE_TOKEN_ADDRESS", address(0x0d91EbB16291873A0c67158f578ec249F4321b49));
        uint8 maxWeeks = uint8(vm.envOr("MAX_WEEKS", uint256(2)));
        string memory tokenName = vm.envOr("TOKEN_NAME", string("Staked Token"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("sToken"));

        console.log("Initializing StakedToken at:", stakedTokenAddress);
        console.log("Base Token:", baseToken);
        console.log("Max Weeks:", maxWeeks);
        console.log("Token Name:", tokenName);
        console.log("Token Symbol:", tokenSymbol);

        // Initialize the contract
        stakedToken stToken = stakedToken(stakedTokenAddress);
        stToken.initialize(baseToken, maxWeeks, tokenName, tokenSymbol);

        console.log("StakedToken initialized successfully!");

        vm.stopBroadcast();
    }
}
