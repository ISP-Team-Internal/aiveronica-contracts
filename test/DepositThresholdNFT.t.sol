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

    function setUp() public {
        // Set up daily token amounts (same as before but direct values)
        dailyTokenAmounts = new uint256[](14);
        dailyTokenAmounts[0] = 1000 * 10 ** 18; // Day 1: 1000 tokens
        dailyTokenAmounts[1] = 1100 * 10 ** 18; // Day 2: 1100 tokens
        dailyTokenAmounts[2] = 1200 * 10 ** 18; // Day 3: 1200 tokens
        dailyTokenAmounts[3] = 1300 * 10 ** 18; // Day 4: 1300 tokens
        dailyTokenAmounts[4] = 1400 * 10 ** 18; // Day 5: 1400 tokens
        dailyTokenAmounts[5] = 1500 * 10 ** 18; // Day 6: 1500 tokens
        dailyTokenAmounts[6] = 1600 * 10 ** 18; // Day 7: 1600 tokens
        dailyTokenAmounts[7] = 1700 * 10 ** 18; // Day 8: 1700 tokens
        dailyTokenAmounts[8] = 2000 * 10 ** 18; // Day 9: 2000 tokens
        dailyTokenAmounts[9] = 2200 * 10 ** 18; // Day 10: 2200 tokens
        dailyTokenAmounts[10] = 2400 * 10 ** 18; // Day 11: 2400 tokens
        dailyTokenAmounts[11] = 2600 * 10 ** 18; // Day 12: 2600 tokens
        dailyTokenAmounts[12] = 2800 * 10 ** 18; // Day 13: 2800 tokens
        dailyTokenAmounts[13] = 3000 * 10 ** 18; // Day 14: 3000 tokens

        // Set up daily whitelist limits (can be different for each day)
        dailyWhitelistLimits = new uint256[](14);
        dailyWhitelistLimits[0] = 1000;
        dailyWhitelistLimits[1] = 2000;
        for (uint256 i = 2; i < 14; i++) {
            dailyWhitelistLimits[i] = 5000; // Using same limit as before, but could be different per day
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
            admin
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
        if (day == 0) {
            vm.warp(STARTING_TIMESTAMP - 1 days);
            return;
        }
        vm.warp(STARTING_TIMESTAMP + (day - 1) * 1 days);
    }

    // --- Admin Function Tests ---

    function testAdminWithdrawToken() public {
        // User1 mints NFT
        warpToDay(1);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(1);
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

    // --- User Function Tests ---

    function testMintBeforeStart() public {
        vm.warp(STARTING_TIMESTAMP - 1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), type(uint256).max);
        vm.expectRevert("Campaign is not active");
        depositNFT.mint();
        vm.stopPrank();
    }

    function testMintAfterEnd() public {
        warpToDay(15);
        vm.startPrank(user1);
        token.approve(address(depositNFT), type(uint256).max);
        vm.expectRevert("Campaign has ended");
        depositNFT.mint();
        vm.stopPrank();
    }

    function testMintDay1() public {
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.dailyWhitelistCount(1), 1);
        assertEq(depositNFT.ownerOf(1), user1);
        assertEq(depositNFT.getNextTokenId(), 2);
    }

    function testTokenRequiredDepositAmount() public {
        uint256[15] memory expectedAmountEachDay = [
            uint256(0),
            1000,
            1100,
            1200,
            1300,
            1400,
            1500,
            1600,
            1700,
            2000,
            2200,
            2400,
            2600,
            2800,
            3000
        ];
        for (uint i = 1; i < 15; i++) {
            warpToDay(i);
            assertEq(
                depositNFT.getRequiredDepositAmount(i) / 10 ** 18,
                expectedAmountEachDay[i]
            );
        }
    }

    function testMintDay9() public {
        warpToDay(9);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(9);
        assertEq(requiredAmount, dailyTokenAmounts[8]); // Day 9 should require 2000 token

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.dailyWhitelistCount(9), 1);
        assertEq(depositNFT.ownerOf(1), user1);
    }

    function testWhitelistLimitReached() public {
        warpToDay(1);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(1);

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
        warpToDay(0);
        assertEq(depositNFT.getCurrentDay(), 0); // Before start
        warpToDay(1);
        assertEq(depositNFT.getCurrentDay(), 1);
        warpToDay(14);
        assertEq(depositNFT.getCurrentDay(), 14);

        // After campaign ends, the current day should return 0
        vm.warp(STARTING_TIMESTAMP + CAMPAIGN_DURATION + 1);
        assertEq(depositNFT.getCurrentDay(), 0);
    }

    function testGetRemainingWhitelistsToday() public {
        warpToDay(1);
        assertEq(
            depositNFT.getRemainingWhitelistsToday(),
            dailyWhitelistLimits[0]
        );

        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(1);
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
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.ownerOf(1), user1);
        assertEq(depositNFT.balanceOf(user1), 1);
    }

    function testNFTTokenCounter() public {
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);

        assertEq(depositNFT.getNextTokenId(), 1);

        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();
        vm.stopPrank();

        assertEq(depositNFT.getNextTokenId(), 2);
    }

    function testCannotMintTwiceInSameDay() public {
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);

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
        // Mint on day 1
        warpToDay(1);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();
        vm.stopPrank();

        // Mint on day 2
        warpToDay(2);
        uint256 requiredAmount2 = depositNFT.getRequiredDepositAmount(2);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount2);
        depositNFT.mint();
        vm.stopPrank();

        // Verify user1 has 2 NFTs
        assertEq(depositNFT.balanceOf(user1), 2);
    }

    function testMultipleUsersSameDayDifferentUsers() public {
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);

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
        // Mint on day 1
        warpToDay(1);
        uint256 requiredAmount1 = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount1);
        depositNFT.mint();

        // Verify last purchase day is recorded correctly
        assertEq(depositNFT.lastPurchaseDay(user1), 1);
        vm.stopPrank();

        // Mint on day 3 (skipping day 2)
        warpToDay(3);
        uint256 requiredAmount3 = depositNFT.getRequiredDepositAmount(3);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount3);
        depositNFT.mint();

        // Verify last purchase day is updated
        assertEq(depositNFT.lastPurchaseDay(user1), 3);
        vm.stopPrank();
    }

    function testCannotTransferNFT() public {
        // First mint an NFT
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);
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
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);
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
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);
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
        warpToDay(1);
        uint256 requiredAmount = depositNFT.getRequiredDepositAmount(1);
        vm.startPrank(user1);
        token.approve(address(depositNFT), requiredAmount);
        depositNFT.mint();

        // Try to set approval for all to user2
        vm.expectRevert("DepositThresholdNFT: Operator approvals are disabled");
        depositNFT.setApprovalForAll(user2, true);
        vm.stopPrank();
    }
}
