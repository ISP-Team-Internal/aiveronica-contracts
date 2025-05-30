// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

contract AirdropAIV is Script {
    // AIV token address on Base mainnet (based on deployment broadcasts)
    address constant AIV_TOKEN = 0x0d91EbB16291873A0c67158f578ec249F4321b49;

    // Option 1: Directly define distribution list in code
    function getHardcodedDistribution()
        internal
        pure
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        // Define your airdrop distribution here
        recipients = new address[](5); // Adjust size as needed
        amounts = new uint256[](5);

        // Example distribution - replace with your actual recipients and amounts
        recipients[0] = 0x742E8D0aed6E21e2f8dABf7C8D9b3d96aF61F5a4;
        amounts[0] = 1000 * 10 ** 18; // 1000 AIV tokens

        recipients[1] = 0x1234567890123456789012345678901234567890;
        amounts[1] = 500 * 10 ** 18; // 500 AIV tokens

        recipients[2] = 0xABcdEFABcdEFabcdEfAbCdefabcdeFABcDEFabCD;
        amounts[2] = 750 * 10 ** 18; // 750 AIV tokens

        recipients[3] = 0x9876543210987654321098765432109876543210;
        amounts[3] = 250 * 10 ** 18; // 250 AIV tokens

        recipients[4] = 0xfEDCBA0987654321FeDcbA0987654321fedCBA09;
        amounts[4] = 300 * 10 ** 18; // 300 AIV tokens

        return (recipients, amounts);
    }

    // Option 2: Load distribution from environment variables (Alternative to CSV)
    function getEnvDistribution()
        internal
        view
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        // Try to load from environment variables first
        string memory recipientsEnv = vm.envOr("AIRDROP_RECIPIENTS", string(""));
        string memory amountsEnv = vm.envOr("AIRDROP_AMOUNTS", string(""));
        
        if (bytes(recipientsEnv).length > 0 && bytes(amountsEnv).length > 0) {
            console.log("Loading distribution from environment variables...");
            string[] memory recipientStrings = splitString(recipientsEnv, ",");
            string[] memory amountStrings = splitString(amountsEnv, ",");
            
            require(recipientStrings.length == amountStrings.length, "Mismatched recipients and amounts count");
            
            recipients = new address[](recipientStrings.length);
            amounts = new uint256[](recipientStrings.length);
            
            for (uint256 i = 0; i < recipientStrings.length; i++) {
                recipients[i] = vm.parseAddress(trim(recipientStrings[i]));
                amounts[i] = vm.parseUint(trim(amountStrings[i]));
            }
            
            return (recipients, amounts);
        }
        
        console.log("No environment variables found, using hardcoded distribution");
        return getHardcodedDistribution();
    }

    // Option 3: Load distribution from CSV file
    function getCSVDistribution()
        internal
        view
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        string memory csvPath = "./script/airdrop_distribution.csv";

        try vm.readFile(csvPath) returns (string memory csvContent) {
            console.log("Successfully loaded CSV file");
            return parseCSV(csvContent);
        } catch Error(string memory reason) {
            console.log("Failed to read CSV file:", reason);
            console.log("Falling back to environment variables...");
            return getEnvDistribution();
        } catch {
            console.log("Failed to read CSV file: Unknown error");
            console.log("Falling back to environment variables...");
            return getEnvDistribution();
        }
    }

    function parseCSV(
        string memory csvContent
    )
        internal
        pure
        returns (address[] memory recipients, uint256[] memory amounts)
    {
        // Split by newlines to get rows
        string[] memory lines = splitString(csvContent, "\n");

        // Skip header row if present, adjust based on your CSV format
        uint256 startIndex = 0;
        if (lines.length > 0) {
            // Check if first line contains "address" or "recipient" (header)
            if (
                contains(lines[0], "address") || contains(lines[0], "recipient")
            ) {
                startIndex = 1;
            }
        }

        uint256 dataLines = lines.length - startIndex;
        recipients = new address[](dataLines);
        amounts = new uint256[](dataLines);

        for (uint256 i = startIndex; i < lines.length; i++) {
            if (bytes(lines[i]).length > 0) {
                string[] memory columns = splitString(lines[i], ",");
                if (columns.length >= 2) {
                    // Parse address (remove any whitespace)
                    recipients[i - startIndex] = vm.parseAddress(
                        trim(columns[0])
                    );
                    // Parse amount (assuming it's in wei or adjust decimals as needed)
                    amounts[i - startIndex] = vm.parseUint(trim(columns[1]));
                }
            }
        }

        return (recipients, amounts);
    }

    function run() external {
        // Load private key from environment
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("AIV Token address:", AIV_TOKEN);

        // Choose distribution method with priority: CSV > ENV > Hardcoded
        string memory distributionMethod = vm.envOr("DISTRIBUTION_METHOD", string("auto"));
        
        address[] memory recipients;
        uint256[] memory amounts;

        if (keccak256(bytes(distributionMethod)) == keccak256(bytes("csv"))) {
            console.log("Forced CSV mode");
            (recipients, amounts) = getCSVDistribution();
        } else if (keccak256(bytes(distributionMethod)) == keccak256(bytes("env"))) {
            console.log("Forced ENV mode");
            (recipients, amounts) = getEnvDistribution();
        } else if (keccak256(bytes(distributionMethod)) == keccak256(bytes("hardcoded"))) {
            console.log("Forced hardcoded mode");
            (recipients, amounts) = getHardcodedDistribution();
        } else {
            // Auto mode - try CSV first, then ENV, then hardcoded
            console.log("Auto mode - trying CSV first...");
            (recipients, amounts) = getCSVDistribution();
        }

        require(
            recipients.length == amounts.length,
            "Recipients and amounts arrays must have same length"
        );
        require(recipients.length > 0, "No recipients specified");

        console.log("Number of recipients:", recipients.length);

        // Start broadcasting transactions
        vm.startBroadcast(deployerPrivateKey);

        IERC20 aivToken = IERC20(AIV_TOKEN);

        // Check deployer's balance
        uint256 deployerBalance = aivToken.balanceOf(deployer);
        console.log("Deployer AIV balance:", deployerBalance / 10**18, "AIV");

        // Calculate total amount needed
        uint256 totalAmount = 0;
        for (uint256 i = 0; i < amounts.length; i++) {
            totalAmount += amounts[i];
        }
        console.log("Total AIV needed:", totalAmount / 10 ** 18, "AIV");

        require(
            deployerBalance >= totalAmount,
            "Insufficient AIV balance for airdrop"
        );

        // Perform airdrop
        uint256 successfulTransfers = 0;
        for (uint256 i = 0; i < recipients.length; i++) {
            if (amounts[i] > 0 && recipients[i] != address(0)) {
                try aivToken.transfer(recipients[i], amounts[i]) returns (
                    bool success
                ) {
                    if (success) {
                        console.log(
                            "Sent",
                            amounts[i] / 10**18,
                            "AIV to",
                            recipients[i]
                        );
                        successfulTransfers++;
                    } else {
                        console.log("Failed to send to", recipients[i]);
                    }
                } catch {
                    console.log("Transfer failed for", recipients[i]);
                }
            } else {
                console.log(
                    "Skipping invalid recipient or amount:",
                    recipients[i],
                    amounts[i]
                );
            }
        }

        console.log("Airdrop completed!");
        console.log(
            "Successful transfers:",
            successfulTransfers,
            "out of",
            recipients.length
        );

        vm.stopBroadcast();
    }

    // Helper functions for string manipulation
    function splitString(
        string memory str,
        string memory delimiter
    ) internal pure returns (string[] memory) {
        bytes memory strBytes = bytes(str);
        bytes memory delimiterBytes = bytes(delimiter);

        if (strBytes.length == 0) {
            return new string[](0);
        }

        // Count occurrences of delimiter
        uint256 count = 1;
        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                count++;
                i += delimiterBytes.length - 1;
            }
        }

        string[] memory result = new string[](count);
        uint256 resultIndex = 0;
        uint256 lastIndex = 0;

        for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < delimiterBytes.length; j++) {
                if (strBytes[i + j] != delimiterBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                result[resultIndex] = substring(str, lastIndex, i);
                resultIndex++;
                lastIndex = i + delimiterBytes.length;
                i += delimiterBytes.length - 1;
            }
        }

        // Add the last part
        result[resultIndex] = substring(str, lastIndex, strBytes.length);

        return result;
    }

    function substring(
        string memory str,
        uint256 startIndex,
        uint256 endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);

        for (uint256 i = startIndex; i < endIndex; i++) {
            result[i - startIndex] = strBytes[i];
        }

        return string(result);
    }

    function contains(
        string memory str,
        string memory substr
    ) internal pure returns (bool) {
        bytes memory strBytes = bytes(str);
        bytes memory substrBytes = bytes(substr);

        if (substrBytes.length > strBytes.length) {
            return false;
        }

        for (uint256 i = 0; i <= strBytes.length - substrBytes.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (strBytes[i + j] != substrBytes[j]) {
                    found = false;
                    break;
                }
            }
            if (found) {
                return true;
            }
        }

        return false;
    }

    function trim(string memory str) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);

        if (strBytes.length == 0) {
            return str;
        }

        uint256 start = 0;
        uint256 end = strBytes.length;

        // Find start (skip leading whitespace)
        while (
            start < strBytes.length &&
            (strBytes[start] == 0x20 || strBytes[start] == 0x09)
        ) {
            start++;
        }

        // Find end (skip trailing whitespace)
        while (
            end > start &&
            (strBytes[end - 1] == 0x20 || strBytes[end - 1] == 0x09)
        ) {
            end--;
        }

        return substring(str, start, end);
    }
}
