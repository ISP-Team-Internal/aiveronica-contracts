// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/TokenStaking.sol";
import "../src/TestToken.sol";

contract TokenStakingTest is Test {
    TokenStaking stakingContract;
    TestToken stakingToken;
    address admin = address(0x1);
    address user1 = address(0x2);
    address user2 = address(0x3);

    uint256 constant INITIAL_BALANCE = 10_000 * 10**18;
    uint256[] stakingPeriods;

    function setUp() public {
        // Setup staking periods (in seconds)
        stakingPeriods = new uint256[](3);
        stakingPeriods[0] = 7 days;   // 1 week
        stakingPeriods[1] = 30 days;  // 1 month
        stakingPeriods[2] = 90 days;  // 3 months

        // Deploy token contract
        stakingToken = new TestToken(admin, "Staking Token", "STK");

        // Deploy staking contract
        stakingContract = new TokenStaking(address(stakingToken), stakingPeriods);

        // Mint tokens to users
        vm.startPrank(admin);
        stakingToken.mint(user1, INITIAL_BALANCE);
        stakingToken.mint(user2, INITIAL_BALANCE);
        vm.stopPrank();
    }

    // --- Helper Functions ---
    function approveAndStake(address user, uint256 amount, uint256 periodIndex) internal returns (uint256 stakeIndex, bool isNewStake) {
        vm.startPrank(user);
        stakingToken.approve(address(stakingContract), amount);
        (uint256 index, bool newStake) = stakingContract.stake(amount, periodIndex);
        vm.stopPrank();
        return (index, newStake);
    }

    function warpForward(uint256 timeInSeconds) internal {
        vm.warp(block.timestamp + timeInSeconds);
    }

    // --- Basic Functionality Tests ---
    function testGetStakingPeriods() public {
        uint256[] memory periods = stakingContract.getStakingPeriods();
        assertEq(periods.length, stakingPeriods.length);
        
        for (uint256 i = 0; i < periods.length; i++) {
            assertEq(periods[i], stakingPeriods[i]);
        }
    }

    function testStake() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 periodIndex = 0; // 7 days
        
        uint256 initialBalance = stakingToken.balanceOf(user1);
        
        (uint256 stakeIndex, bool isNewStake) = approveAndStake(user1, stakeAmount, periodIndex);
        
        // Check user balance decreased
        assertEq(stakingToken.balanceOf(user1), initialBalance - stakeAmount);
        
        // Check stake info
        assertEq(stakingContract.getStakeCount(user1), 1);
        assertEq(stakingContract.getActiveStakeCount(user1), 1);
        assertEq(stakeIndex, 0);
        assertTrue(isNewStake);
        
        (uint256 amount, uint256 startTime, uint256 period, bool withdrawn, uint256 timeLeft) = 
            stakingContract.getStakeInfo(user1, 0);
            
        assertEq(amount, stakeAmount);
        assertEq(period, stakingPeriods[periodIndex]);
        assertEq(withdrawn, false);
        assertEq(timeLeft, stakingPeriods[periodIndex]); // Full time left
    }

    function testStakeReplacement() public {
        // First stake
        (uint256 stakeIndex1, ) = approveAndStake(user1, 1000 * 10**18, 0);
        
        // Withdraw it
        warpForward(7 days + 1);
        vm.prank(user1);
        (bool success, ) = stakingContract.withdraw(stakeIndex1);
        assertTrue(success);
        
        // Verify it's marked as withdrawn
        (, , , bool withdrawn, ) = stakingContract.getStakeInfo(user1, stakeIndex1);
        assertTrue(withdrawn);
        assertEq(stakingContract.getActiveStakeCount(user1), 0);
        
        // Create a new stake - should replace the withdrawn one
        (uint256 stakeIndex2, bool isNewStake) = approveAndStake(user1, 2000 * 10**18, 1);
        
        // Check that the index is the same and it's not a new stake
        assertEq(stakeIndex2, stakeIndex1);
        assertFalse(isNewStake);
        
        // Verify the stake was properly replaced
        (uint256 amount, , uint256 period, bool stillWithdrawn, ) = 
            stakingContract.getStakeInfo(user1, stakeIndex1);
            
        assertEq(amount, 2000 * 10**18);
        assertEq(period, stakingPeriods[1]);
        assertFalse(stillWithdrawn);
        assertEq(stakingContract.getActiveStakeCount(user1), 1);
    }

    function testMultipleStakes() public {
        // First stake
        (uint256 stakeIndex1, bool isNewStake1) = approveAndStake(user1, 500 * 10**18, 0); // 7 days
        
        // Second stake
        (uint256 stakeIndex2, bool isNewStake2) = approveAndStake(user1, 1000 * 10**18, 1); // 30 days
        
        // Check stake count
        assertEq(stakingContract.getStakeCount(user1), 2);
        assertEq(stakingContract.getActiveStakeCount(user1), 2);
        
        // Verify indices and that they're new stakes
        assertEq(stakeIndex1, 0);
        assertEq(stakeIndex2, 1);
        assertTrue(isNewStake1);
        assertTrue(isNewStake2);
        
        // Check first stake
        (uint256 amount1, , uint256 period1, bool withdrawn1, ) = 
            stakingContract.getStakeInfo(user1, 0);
            
        assertEq(amount1, 500 * 10**18);
        assertEq(period1, stakingPeriods[0]);
        assertEq(withdrawn1, false);
        
        // Check second stake
        (uint256 amount2, , uint256 period2, bool withdrawn2, ) = 
            stakingContract.getStakeInfo(user1, 1);
            
        assertEq(amount2, 1000 * 10**18);
        assertEq(period2, stakingPeriods[1]);
        assertEq(withdrawn2, false);
    }

    function testWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        (uint256 stakeIndex, ) = approveAndStake(user1, stakeAmount, 0); // 7 days
        
        uint256 initialBalance = stakingToken.balanceOf(user1);
        
        // Warp past the staking period
        warpForward(7 days + 1);
        
        // Withdraw the stake
        vm.prank(user1);
        (bool success, uint256 withdrawnAmount) = stakingContract.withdraw(stakeIndex);
        
        // Check return values
        assertTrue(success);
        assertEq(withdrawnAmount, stakeAmount);
        
        // Check balance is back to initial
        assertEq(stakingToken.balanceOf(user1), initialBalance + stakeAmount);
        
        // Check stake is marked as withdrawn and active count decreased
        (, , , bool withdrawn, ) = stakingContract.getStakeInfo(user1, 0);
        assertEq(withdrawn, true);
        assertEq(stakingContract.getActiveStakeCount(user1), 0);
    }
    
    // --- Time-based Tests ---
    function testTimeLeftUpdates() public {
        approveAndStake(user1, 1000 * 10**18, 1); // 30 days
        
        // Check initial time left
        (, , , , uint256 initialTimeLeft) = stakingContract.getStakeInfo(user1, 0);
        assertEq(initialTimeLeft, 30 days);
        
        // Warp forward 10 days
        warpForward(10 days);
        
        // Check updated time left
        (, , , , uint256 updatedTimeLeft) = stakingContract.getStakeInfo(user1, 0);
        assertEq(updatedTimeLeft, 20 days);
        
        // Warp past lock period
        warpForward(30 days);
        
        // Time left should be 0
        (, , , , uint256 finalTimeLeft) = stakingContract.getStakeInfo(user1, 0);
        assertEq(finalTimeLeft, 0);
    }

    // --- Failure Tests ---
    function testCannotWithdrawEarly() public {
        (uint256 stakeIndex, ) = approveAndStake(user1, 1000 * 10**18, 0); // 7 days
        
        // Try to withdraw early
        vm.startPrank(user1);
        vm.expectRevert("Lock period not ended");
        stakingContract.withdraw(stakeIndex);
        vm.stopPrank();
    }
    
    function testCannotWithdrawTwice() public {
        (uint256 stakeIndex, ) = approveAndStake(user1, 1000 * 10**18, 0); // 7 days
        
        // Warp past lock period
        warpForward(7 days + 1);
        
        // First withdrawal
        vm.prank(user1);
        (bool success, ) = stakingContract.withdraw(stakeIndex);
        assertTrue(success);
        
        // Try to withdraw again
        vm.startPrank(user1);
        vm.expectRevert("Already withdrawn");
        stakingContract.withdraw(stakeIndex);
        vm.stopPrank();
    }
    
    function testCannotStakeZero() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        vm.expectRevert("Amount must be greater than 0");
        stakingContract.stake(0, 0);
        vm.stopPrank();
    }
    
    function testCannotStakeBelowMinimum() public {
        uint256 minAmount = stakingContract.MIN_STAKE_AMOUNT_FACTOR();
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), minAmount);
        vm.expectRevert("Amount below minimum stake threshold");
        stakingContract.stake(minAmount - 1, 0);
        vm.stopPrank();
    }
    
    function testCannotUseInvalidPeriodIndex() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        vm.expectRevert("Invalid period index");
        stakingContract.stake(1000 * 10**18, 99); // Invalid period index
        vm.stopPrank();
    }
    
    function testCannotWithdrawInvalidStakeIndex() public {
        vm.startPrank(user1);
        vm.expectRevert("Invalid stake index");
        stakingContract.withdraw(0); // User has no stakes
        vm.stopPrank();
    }
    
    function testMultipleUsersStaking() public {
        // User 1 stakes
        (uint256 stakeIndex1, ) = approveAndStake(user1, 1000 * 10**18, 0);
        
        // User 2 stakes
        (uint256 stakeIndex2, ) = approveAndStake(user2, 2000 * 10**18, 1);
        
        // Check user 1 stake
        (uint256 amount1, , , , ) = stakingContract.getStakeInfo(user1, stakeIndex1);
        assertEq(amount1, 1000 * 10**18);
        
        // Check user 2 stake
        (uint256 amount2, , , , ) = stakingContract.getStakeInfo(user2, stakeIndex2);
        assertEq(amount2, 2000 * 10**18);
        
        // User 2 cannot withdraw user 1's stake
        vm.startPrank(user2);
        vm.expectRevert("Invalid stake index");
        stakingContract.withdraw(1); // User 2 only has one stake at index 0
        vm.stopPrank();
    }
    
    function testMaximumStakesLimit() public {
        uint256 maxStakes = stakingContract.MAX_STAKES_PER_USER();
        uint256 stakeAmount = 500 * 10**18; // Smaller amount to prevent running out of tokens
        
        // Create maximum number of stakes
        for (uint256 i = 0; i < maxStakes; i++) {
            approveAndStake(user1, stakeAmount, 0);
        }
        
        // Verify we have reached the maximum
        assertEq(stakingContract.getActiveStakeCount(user1), maxStakes);
        assertEq(stakingContract.getStakeCount(user1), maxStakes);
        
        // Try to create one more stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        vm.expectRevert("Maximum active stakes reached");
        stakingContract.stake(stakeAmount, 0);
        vm.stopPrank();
        
        // Withdraw one stake to free up space
        warpForward(7 days + 1);
        vm.prank(user1);
        stakingContract.withdraw(0);
        
        // Verify active count decreased but total count remained the same
        assertEq(stakingContract.getActiveStakeCount(user1), maxStakes - 1);
        assertEq(stakingContract.getStakeCount(user1), maxStakes);
        
        // Now we should be able to create a new stake
        (uint256 newStakeIndex, bool isNewStake) = approveAndStake(user1, stakeAmount, 0);
        
        // It should have replaced the withdrawn stake
        assertEq(newStakeIndex, 0);
        assertFalse(isNewStake);
    }
}
