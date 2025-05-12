// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DepositThresholdNFT.sol";
import "../src/TestToken.sol";

contract DepositThresholdNFTTest is Test {
    DepositThresholdNFT depositNFT;
    TestToken token;
    address admin = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    uint256 constant STARTING_TIMESTAMP = 1_000_000_000; // Example future timestamp
    uint256 constant CAMPAIGN_DURATION = 14 days;
    uint256[] dailyTokenAmounts;
    uint256[] dailyWhitelistLimits;
    string constant BASE_URI = "https://example.com/metadata/";

    function setUp() public {
        // Reset state
        vm.startPrank(admin);
        if (address(depositNFT) != address(0)) {
            // Reset the contract state if it exists
            vm.etch(address(depositNFT), "");
        }
        vm.stopPrank();

        // Set up daily token amounts (same as before but direct values)
        dailyTokenAmounts = new uint256[](14);
        dailyTokenAmounts[0] = 1000 * 10 ** 18; // Day 0: 1000 tokens
        dailyTokenAmounts[1] = 1100 * 10 ** 18; // Day 1: 1100 tokens
        dailyTokenAmounts[2] = 1200 * 10 ** 18; // Day 2: 1200 tokens
        dailyTokenAmounts[3] = 1300 * 10 ** 18; // Day 3: 1300 tokens
        dailyTokenAmounts[4] = 1400 * 10 ** 18; // Day 4: 1400 tokens
        dailyTokenAmounts[5] = 1500 * 10 ** 18; // Day 5: 1500 tokens
        dailyTokenAmounts[6] = 1600 * 10 ** 18; // Day 6: 1600 tokens
        dailyTokenAmounts[7] = 1700 * 10 ** 18; // Day 7: 1700 tokens
        dailyTokenAmounts[8] = 2000 * 10 ** 18; // Day 8: 2000 tokens
        dailyTokenAmounts[9] = 2200 * 10 ** 18; // Day 9: 2200 tokens
        dailyTokenAmounts[10] = 2400 * 10 ** 18; // Day 10: 2400 tokens
        dailyTokenAmounts[11] = 2600 * 10 ** 18; // Day 11: 2600 tokens
        dailyTokenAmounts[12] = 2800 * 10 ** 18; // Day 12: 2800 tokens
        dailyTokenAmounts[13] = 3000 * 10 ** 18; // Day 13: 3000 tokens

        // Set up daily whitelist limits (can be different for each day)
        dailyWhitelistLimits = new uint256[](14);
        dailyWhitelistLimits[0] = 1000;
        dailyWhitelistLimits[1] = 2000;
        for (uint256 i = 2; i < 14; i++) {
            dailyWhitelistLimits[i] = 5000;
        }

        // Deploy the TestToken contracts
        token = new TestToken(admin, "Pixel", "PIX");

        // Deploy the DepositThresholdNFT with new constructor
        depositNFT = new DepositThresholdNFT(
            STARTING_TIMESTAMP,
            address(token),
            dailyTokenAmounts,
            dailyWhitelistLimits,
            CAMPAIGN_DURATION,
            admin,
            BASE_URI
        );

        // Mint tokens to users
        vm.startPrank(admin);
        token.mint(user1, 100_000 * 10 ** 18);
        token.mint(user2, 100_000 * 10 ** 18);
        vm.stopPrank();

        // Warp to the start of the campaign
        vm.warp(STARTING_TIMESTAMP);
    }

    // --- Helper Functions ---

    function warpToDay(uint256 day) internal {
        if (day == type(uint256).max) {
            vm.warp(STARTING_TIMESTAMP - 1 days);
            return;
        }
        vm.warp(STARTING_TIMESTAMP + day * 1 days);
    }

    // --- Admin Function Tests ---

    function testAdminWithdrawToken() public {
        // User1 mints NFT
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // Warp to after campaign end
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);

        // Admin withdraws token
        vm.prank(admin);
        depositNFT.adminWithdraw(requiredAmount1, admin);

        assertEq(token.balanceOf(admin), requiredAmount1);
    }

    function testAdminWithdrawAll() public {
        // User1 mints NFT
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // Warp to after campaign end
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);

        // Admin withdraws all tokens
        vm.prank(admin);
        depositNFT.adminWithdrawAll();

        assertEq(token.balanceOf(admin), requiredAmount1);
        assertEq(token.balanceOf(address(depositNFT)), 0);
    }

    function testAdminWithdrawAllMultipleDeposits() public {
        // User1 mints NFT
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // User2 mints NFT
        warpToDay(1);
        uint256 requiredAmount2 = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user2);
        token.approve(address(depositNFT), requiredAmount2);
        depositNFT.mint();
        vm.stopPrank();

        // Warp to after campaign end
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);

        // Admin withdraws all tokens
        vm.prank(admin);
        depositNFT.adminWithdrawAll();

        assertEq(token.balanceOf(admin), requiredAmount1 + requiredAmount2);
        assertEq(token.balanceOf(address(depositNFT)), 0);
    }

    function testNonAdminCannotWithdrawAll() public {
        // User1 mints NFT
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // Warp to after campaign end
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);

        // Try to withdraw all tokens as non-admin
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.adminWithdrawAll();
        vm.stopPrank();
    }

    function testCannotAdminWithdrawAllZeroBalance() public {
        // Warp to after campaign end
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);

        // Try to withdraw all tokens when contract has zero balance
        vm.prank(admin);
        vm.expectRevert("No tokens to withdraw");
        depositNFT.adminWithdrawAll();
    }

    // --- User Function Tests ---

    function testMintBeforeStart() public {
        vm.warp(STARTING_TIMESTAMP - 1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), type(uint256).max);
        vm.expectRevert("Campaign is not active or has ended");
        depositNFT.mint();
        vm.stopPrank();
    }

    function testMintAfterEnd() public {
        warpToDay(14);
        vm.startPrank(user1);
        token.approve(address(depositNFT), type(uint256).max);
        vm.expectRevert("Campaign is not active or has ended");
        depositNFT.mint();
        vm.stopPrank();
    }

    function testMintDay0() public {
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.dailyWhitelistCount(0), 1);
        assertEq(depositNFT.ownerOf(1), user1);
        assertEq(depositNFT.getNextTokenId(), 2);
    }

    function testTokenRequiredDepositAmount() public {
        uint256[] memory expectedAmountEachDay = new uint256[](14);
        expectedAmountEachDay[0] = 1000;
        expectedAmountEachDay[1] = 1100;
        expectedAmountEachDay[2] = 1200;
        expectedAmountEachDay[3] = 1300;
        expectedAmountEachDay[4] = 1400;
        expectedAmountEachDay[5] = 1500;
        expectedAmountEachDay[6] = 1600;
        expectedAmountEachDay[7] = 1700;
        expectedAmountEachDay[8] = 2000;
        expectedAmountEachDay[9] = 2200;
        expectedAmountEachDay[10] = 2400;
        expectedAmountEachDay[11] = 2600;
        expectedAmountEachDay[12] = 2800;
        expectedAmountEachDay[13] = 3000;

        for (uint i = 0; i < 14; i++) {
            warpToDay(i);
            assertEq(
                depositNFT.getRequiredDepositAmount(i) / 10 ** 18,
                expectedAmountEachDay[i]
            );
        }
    }

    function testMintDay8() public {
        warpToDay(8);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(8);
        assertEq(requiredAmount, dailyTokenAmounts[8]); // Day 8 should require 2000 token

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.dailyWhitelistCount(8), 1);
        assertEq(depositNFT.ownerOf(1), user1);
    }

    function testWhitelistLimitReached() public {
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);

        // Fill up the whitelist limit with NFT mints
        for (uint256 i = 0; i < dailyWhitelistLimits[0]; i++) {
            address user = address(
                uint160(uint256(keccak256(abi.encodePacked(i))))
            );
            vm.startPrank(admin);
            token.mint(user, requiredAmount1);
            vm.stopPrank();
            vm.startPrank(user);
            token.approve(address(depositNFT), requiredAmount1);
            depositNFT.mint();
            vm.stopPrank();
        }

        // Try to mint NFT (should fail due to whitelist limit)
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        vm.expectRevert("Daily whitelist limit reached");
        depositNFT.mint();
        vm.stopPrank();
    }

    // --- View Function Tests ---

    function testGetCurrentDay() public {
        warpToDay(type(uint256).max);
        assertEq(depositNFT.getCurrentDay(), type(uint256).max); // Before start
        warpToDay(0);
        assertEq(depositNFT.getCurrentDay(), 0);
        warpToDay(13);
        assertEq(depositNFT.getCurrentDay(), 13);

        // After campaign ends, the current day should return type(uint256).max
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);
        assertEq(depositNFT.getCurrentDay(), type(uint256).max);
    }

    function testGetRemainingWhitelistsToday() public {
        warpToDay(0);
        assertEq(
            depositNFT.getRemainingWhitelistsToday(),
            dailyWhitelistLimits[0]
        );

        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(
            depositNFT.getRemainingWhitelistsToday(),
            dailyWhitelistLimits[0] - 1
        );
    }

    // Test NFT specific functionality
    function testNFTOwnership() public {
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.ownerOf(1), user1);
        assertEq(depositNFT.balanceOf(user1), 1);
    }

    function testNFTTokenCounter() public {
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);

        assertEq(depositNFT.getNextTokenId(), 1);

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.getNextTokenId(), 2);
    }

    function testCannotMintTwiceInSameDay() public {
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);

        // First mint should succeed
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount * 2); // Approve enough for two mints
        depositNFT.mint();

        // Second mint in same day should fail
        vm.expectRevert("Already purchased today");
        depositNFT.mint();
        vm.stopPrank();
    }

    function testCanMintOnDifferentDays() public {
        // Mint on day 0
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // Mint on day 1
        warpToDay(1);
        uint256 requiredAmount2 = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount2);
        depositNFT.mint();
        vm.stopPrank();

        // Verify user1 has 2 NFTs
        assertEq(depositNFT.balanceOf(user1), 2);
    }

    function testMultipleUsersSameDayDifferentUsers() public {
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);

        // user1 mints
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // user2 mints on same day
        vm.startPrank(user2);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // Verify both users have 1 NFT each
        assertEq(depositNFT.balanceOf(user1), 1);
        assertEq(depositNFT.balanceOf(user2), 1);
    }

    function testLastPurchaseDayTracking() public {
        // Mint on day 0
        warpToDay(0);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();

        // Verify last purchase day is recorded correctly
        assertEq(depositNFT.lastPurchaseDay(user1), 0);
        vm.stopPrank();

        // Mint on day 2 (skipping day 1)
        warpToDay(2);
        uint256 requiredAmount3 = depositNFT.getRequiredDepositAmount(2);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount3);
        depositNFT.mint();

        // Verify last purchase day is updated
        assertEq(depositNFT.lastPurchaseDay(user1), 2);
        vm.stopPrank();
    }

    function testCannotTransferNFT() public {
        // First mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();

        // Try to transfer the NFT to user2
        vm.expectRevert("DepositThresholdNFT: Tokens are non-transferrable");
        depositNFT.transferFrom(user1, user2, 1);
        vm.stopPrank();
    }

    function testCannotSafeTransferNFT() public {
        // First mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();

        // Try to safe transfer the NFT to user2
        vm.expectRevert("DepositThresholdNFT: Tokens are non-transferrable");
        depositNFT.safeTransferFrom(user1, user2, 1, "");
        vm.stopPrank();
    }

    function testCannotApproveNFT() public {
        // First mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();

        // Try to approve user2 to transfer the NFT
        vm.expectRevert("DepositThresholdNFT: Approvals are disabled");
        depositNFT.approve(user2, 1);
        vm.stopPrank();
    }

    function testCannotSetApprovalForAll() public {
        // First mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();

        // Try to set approval for all to user2
        vm.expectRevert("DepositThresholdNFT: Operator approvals are disabled");
        depositNFT.setApprovalForAll(user2, true);
        vm.stopPrank();
    }

    // --- Pause Function Tests ---

    function testPauseAndUnpause() public {
        // Admin can pause
        vm.prank(admin);
        depositNFT.pause();

        // Cannot mint while paused
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        depositNFT.mint();
        vm.stopPrank();

        // Admin can unpause
        vm.prank(admin);
        depositNFT.unpause();

        // Can mint after unpause
        vm.startPrank(user1);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.ownerOf(1), user1);
    }

    function testNonAdminCannotPause() public {
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.pause();
        vm.stopPrank();
    }

    function testNonAdminCannotUnpause() public {
        // First pause as admin
        vm.prank(admin);
        depositNFT.pause();

        // Try to unpause as non-admin
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.unpause();
        vm.stopPrank();
    }

    // --- Emergency Withdrawal Tests ---

    function testAdminCanWithdrawETH() public {
        // Send some ETH to the contract
        vm.deal(address(depositNFT), 1 ether);
        uint256 contractBalance = address(depositNFT).balance;

        // Admin can withdraw ETH
        vm.prank(admin);
        depositNFT.withdrawETH(payable(admin));

        assertEq(address(admin).balance, contractBalance);
        assertEq(address(depositNFT).balance, 0);
    }

    function testAdminCanWithdrawUnexpectedERC20() public {
        // Deploy a different ERC20 token
        TestToken unexpectedToken = new TestToken(admin, "Unexpected", "UNX");

        // Send some tokens to the contract
        vm.startPrank(admin);
        unexpectedToken.mint(address(depositNFT), 1000 * 10 ** 18);
        vm.stopPrank();

        uint256 contractBalance = unexpectedToken.balanceOf(
            address(depositNFT)
        );

        // Admin can withdraw unexpected tokens
        vm.prank(admin);
        depositNFT.withdrawERC20(unexpectedToken, admin);

        assertEq(unexpectedToken.balanceOf(admin), contractBalance);
        assertEq(unexpectedToken.balanceOf(address(depositNFT)), 0);
    }

    function testCannotWithdrawCampaignToken() public {
        // User1 mints NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // Try to withdraw campaign token using emergency withdrawal
        vm.prank(admin);
        vm.expectRevert("Use adminWithdraw for campaign token");
        depositNFT.withdrawERC20(token, admin);
    }

    function testNonAdminCannotWithdrawETH() public {
        // Send some ETH to the contract
        vm.deal(address(depositNFT), 1 ether);

        // Non-admin cannot withdraw ETH
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.withdrawETH(payable(user1));
        vm.stopPrank();
    }

    function testNonAdminCannotWithdrawERC20() public {
        // Deploy a different ERC20 token
        TestToken unexpectedToken = new TestToken(admin, "Unexpected", "UNX");

        // Send some tokens to the contract
        vm.startPrank(admin);
        unexpectedToken.mint(address(depositNFT), 1000 * 10 ** 18);
        vm.stopPrank();

        // Non-admin cannot withdraw tokens
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.withdrawERC20(unexpectedToken, user1);
        vm.stopPrank();
    }

    function testCannotWithdrawToZeroAddress() public {
        // Send some ETH to the contract
        vm.deal(address(depositNFT), 1 ether);

        // Cannot withdraw to zero address
        vm.prank(admin);
        vm.expectRevert("Invalid recipient address");
        depositNFT.withdrawETH(payable(address(0)));
    }

    function testCannotWithdrawZeroAmount() public {
        // Deploy a different ERC20 token
        TestToken unexpectedToken = new TestToken(admin, "Unexpected", "UNX");

        // Send 0 tokens to the contract
        vm.startPrank(admin);
        unexpectedToken.mint(address(depositNFT), 0);
        vm.stopPrank();

        // Cannot withdraw zero amount
        vm.prank(admin);
        vm.expectRevert("No token balance to withdraw");
        depositNFT.withdrawERC20(unexpectedToken, admin);
    }

    // --- Has Purchased Tests ---

    function testHasPurchasedTracking() public {
        // Initially has not purchased
        assertEq(depositNFT.hasPurchased(user1), false);

        // After first purchase
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.hasPurchased(user1), true);
    }

    function testMultipleUsersPurchaseTracking() public {
        // User1 purchases
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // User2 has not purchased
        assertEq(depositNFT.hasPurchased(user2), false);

        // User2 purchases
        vm.startPrank(user2);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // Both users have purchased
        assertEq(depositNFT.hasPurchased(user1), true);
        assertEq(depositNFT.hasPurchased(user2), true);
    }

    function testTokenURI() public {
        // Mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // Check token URI
        // string memory expectedURI = string(abi.encodePacked(BASE_URI, "1"));
        string memory expectedURI = depositNFT.tokenURI(1);
        assertEq(depositNFT.tokenURI(1), expectedURI);
    }

    function testCannotGetTokenURIForNonExistentToken() public {
        vm.expectRevert(
            abi.encodeWithSignature("ERC721NonexistentToken(uint256)", 1)
        );
        depositNFT.tokenURI(1);
    }

    function testAdminCanUpdateBaseURI() public {
        string memory newBaseURI = "https://newexample.com/metadata/";
        vm.prank(admin);
        depositNFT.setBaseURI(newBaseURI);

        // Mint an NFT
        warpToDay(0);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(0);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        // Check token URI with new base URI
        // string memory expectedURI = string(abi.encodePacked(newBaseURI, "1"));
        string memory expectedURI = depositNFT.tokenURI(1);
        string memory result = depositNFT.tokenURI(1);
        console.log("result: %s", result);
        assertEq(result, expectedURI);
    }

    function testNonAdminCannotUpdateBaseURI() public {
        string memory newBaseURI = "https://newexample.com/metadata/";
        vm.startPrank(user1);
        vm.expectRevert(
            abi.encodeWithSignature(
                "OwnableUnauthorizedAccount(address)",
                user1
            )
        );
        depositNFT.setBaseURI(newBaseURI);
        vm.stopPrank();
    }
}
