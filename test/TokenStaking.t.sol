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
    function approveAndStake(address user, uint256 amount, uint256 periodIndex) internal {
        vm.startPrank(user);
        stakingToken.approve(address(stakingContract), amount);
        stakingContract.stake(amount, periodIndex);
        vm.stopPrank();
    }

    function warpForward(uint256 timeInSeconds) internal {
        vm.warp(block.timestamp + timeInSeconds);
    }

    // --- Basic Functionality Tests ---
    function testGetStakingPeriods() public view {
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
        approveAndStake(user1, stakeAmount, periodIndex);
        // Check user balance decreased
        assertEq(stakingToken.balanceOf(user1), initialBalance - stakeAmount);
        // Check stake info
        (uint256 amount, uint256 startTime, uint256 period) = stakingContract.userStake(user1);
        assertEq(amount, stakeAmount);
        assertEq(period, stakingPeriods[periodIndex]);
        assertTrue(startTime > 0);
    }

    function testWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 0); // 7 days
        uint256 initialBalance = stakingToken.balanceOf(user1);
        // Warp past the staking period
        warpForward(7 days + 1);
        // Withdraw the stake
        vm.startPrank(user1);
        (bool success, uint256 withdrawnAmount) = stakingContract.withdraw();
        vm.stopPrank();
        // Check return values
        assertTrue(success);
        assertEq(withdrawnAmount, stakeAmount);
        // Check balance is back to initial
        assertEq(stakingToken.balanceOf(user1), initialBalance + stakeAmount);
    }

    // --- Failure Tests ---
    function testCannotWithdrawEarly() public {
        approveAndStake(user1, 1000 * 10**18, 0); // 7 days
        // Try to withdraw early
        vm.startPrank(user1);
        vm.expectRevert("Stake is not expired");
        stakingContract.withdraw();
        vm.stopPrank();
    }

    function testCannotStakeZero() public {
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        vm.expectRevert("Amount below minimum stake threshold");
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

    function testCannotWithdrawWithoutStake() public {
        vm.startPrank(user1);
        vm.expectRevert("User has not staked before");
        stakingContract.withdraw();
        vm.stopPrank();
    }

    function testMultipleUsersStaking() public {
        // User 1 stakes
        approveAndStake(user1, 1000 * 10**18, 0);
        // User 2 stakes
        approveAndStake(user2, 2000 * 10**18, 1);
        // Check user 1 stake
        (uint256 amount1,,) = stakingContract.userStake(user1);
        assertEq(amount1, 1000 * 10**18);
        // Check user 2 stake
        (uint256 amount2,,) = stakingContract.userStake(user2);
        assertEq(amount2, 2000 * 10**18);
    }

    // --- Extend Staking Tests ---
    function testExtendStakingAfterExpiry() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 initialPeriodIndex = 0; // 7 days
        uint256 newPeriodIndex = 1;     // 30 days

        // User stakes for the initial period
        approveAndStake(user1, stakeAmount, initialPeriodIndex);

        // Warp past the initial staking period to expire the stake
        warpForward(7 days + 1);

        // Extend the stake to a new period
        vm.startPrank(user1);
        stakingContract.extendStaking(newPeriodIndex);
        vm.stopPrank();

        // Check that the stake's period and startTime are updated, amount unchanged
        (uint256 amount, uint256 startTime, uint256 period) = stakingContract.userStake(user1);
        assertEq(amount, stakeAmount);
        assertEq(period, stakingPeriods[newPeriodIndex]);
        // The new startTime should be close to the current block.timestamp
        assertApproxEqAbs(startTime, block.timestamp, 2); // allow 2s drift for test
    }

    function testCannotExtendBeforeExpiry() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 initialPeriodIndex = 0; // 7 days
        uint256 newPeriodIndex = 1;     // 30 days

        approveAndStake(user1, stakeAmount, initialPeriodIndex);

        // Try to extend before the stake is expired
        vm.startPrank(user1);
        vm.expectRevert("Stake is not expired");
        stakingContract.extendStaking(newPeriodIndex);
        vm.stopPrank();
    }

    function testCannotExtendWithInvalidPeriodIndex() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 initialPeriodIndex = 0; // 7 days
        uint256 invalidPeriodIndex = 99;

        approveAndStake(user1, stakeAmount, initialPeriodIndex);

        // Warp past the initial staking period to expire the stake
        warpForward(7 days + 1);

        // Try to extend with an invalid period index
        vm.startPrank(user1);
        vm.expectRevert("Invalid period index");
        stakingContract.extendStaking(invalidPeriodIndex);
        vm.stopPrank();
    }

    function testCannotExtendWithoutStake() public {
        uint256 newPeriodIndex = 1; // 30 days

        vm.startPrank(user1);
        vm.expectRevert("User has not staked before");
        stakingContract.extendStaking(newPeriodIndex);
        vm.stopPrank();
    }

    // --- Additional Revert Tests ---
    function testCannotStakeWithShorterPeriod() public {
        // First stake with a longer period (30 days)
        approveAndStake(user1, 1000 * 10**18, 1); // 30 days
        
        // Try to stake again with a shorter period (7 days)
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        vm.expectRevert("New stake period is shorter than the previous stake");
        stakingContract.stake(1000 * 10**18, 0); // 7 days
        vm.stopPrank();
    }

    function testCannotStakeWithZeroTokenAddress() public {
        vm.expectRevert("Invalid token address");
        new TokenStaking(address(0), stakingPeriods);
    }

    function testCannotStakeWithEmptyPeriods() public {
        uint256[] memory emptyPeriods = new uint256[](0);
        vm.expectRevert("Must provide at least one staking period");
        new TokenStaking(address(stakingToken), emptyPeriods);
    }

    function testCannotStakeWithZeroPeriod() public {
        uint256[] memory invalidPeriods = new uint256[](1);
        invalidPeriods[0] = 0;
        vm.expectRevert("Staking period must be greater than 0");
        new TokenStaking(address(stakingToken), invalidPeriods);
    }

    function testCannotStakeWithExpiredStakeNotWithdrawn() public {
        // First stake
        approveAndStake(user1, 1000 * 10**18, 0); // 7 days
        
        // Warp past the staking period
        warpForward(7 days + 1);

        // Try to stake again without withdrawing the expired stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        // (uint256 amount, uint256 startTime, uint256 period) = stakingContract.userStake(user1);
        vm.expectRevert("Previous stake is not withdrawn");
        stakingContract.stake(1000 * 10**18, 0);
        vm.stopPrank();
    }

    // --- Pause Functionality Tests ---
    function testPauseUnpause() public {
        vm.startPrank(address(this));
        stakingContract.pauseStaking();
        assertTrue(stakingContract.paused());
        
        // Try to stake while paused
        vm.stopPrank();
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), 1000 * 10**18);
        vm.expectRevert(bytes4(keccak256("EnforcedPause()")));
        stakingContract.stake(1000 * 10**18, 0);
        vm.stopPrank();
        
        // Unpause
        vm.startPrank(address(this));
        stakingContract.unpauseStaking();
        assertFalse(stakingContract.paused());
        vm.stopPrank();
        
        // Now should be able to stake
        approveAndStake(user1, 1000 * 10**18, 0);
    }
    
    function testOnlyOwnerCanPause() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        stakingContract.pauseStaking();
        vm.stopPrank();
    }
    
    // --- Urgent Withdraw Tests ---
    function testUrgentWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        uint256 initialBalance = stakingToken.balanceOf(user1);
        uint256 withdrawAmount = 500 * 10**18;
        
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(withdrawAmount);
        vm.stopPrank();
        
        // Check user balance increased
        assertEq(stakingToken.balanceOf(user1), initialBalance + withdrawAmount);
        
        // Check stake was reduced
        (uint256 remainingAmount,,) = stakingContract.userStake(user1);
        uint256 penaltyAmount = (withdrawAmount * 10) / 100; // 10% for 30 days staking period
        assertEq(remainingAmount, stakeAmount - withdrawAmount - penaltyAmount);
    }
    
    function testCannotUrgentWithdrawAfterExpiry() public {
        approveAndStake(user1, 1000 * 10**18, 0); // 7 days
        
        // Warp past the staking period
        warpForward(7 days + 1);
        
        vm.startPrank(user1);
        vm.expectRevert("Stake is expired, use withdraw() instead");
        stakingContract.urgentWithdraw(500 * 10**18);
        vm.stopPrank();
    }
    
    function testCannotWithdrawMoreThanStaked() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        vm.startPrank(user1);
        vm.expectRevert("Amount to withdraw with penalty is greater than the stake");
        stakingContract.urgentWithdraw(stakeAmount + 1);
        vm.stopPrank();
    }
    
    function testPreventSecondUrgentWithdraw() public {
        approveAndStake(user1, 1000 * 10**18, 1); // 30 days
        
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(500 * 10**18);
        
        vm.expectRevert("User has already urgent withdrawn");
        stakingContract.urgentWithdraw(100 * 10**18);
        vm.stopPrank();
    }

    // --- Penalty Functions Tests ---
    function testPreviewEarlyWithdrawPenalty() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        (,uint256 startTime, uint256 period) = stakingContract.userStake(user1);
        uint256 withdrawAmount = 500 * 10**18;
        
        uint256 penaltyAmount = stakingContract.previewEarlyWithdrawPenalty(
            startTime + period,
            withdrawAmount
        );
        
        // Expected penalty for 30 days left is 10%
        uint256 expectedPenalty = (withdrawAmount * 10) / 100; // 10%
        assertEq(penaltyAmount, expectedPenalty);
    }
    
    // --- New Detailed Penalty Tests ---
    
    function testPenaltyRateUnder30Days() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        approveAndStake(user1, stakeAmount, 2); // 90 days
        
        // Advance time to have only 25 days left
        warpForward(90 days - 25 days);
        
        // Check penalty preview (should be 5% since < 30 days left)
        (,uint256 startTime, uint256 period) = stakingContract.userStake(user1);
        uint256 penaltyAmount = stakingContract.previewEarlyWithdrawPenalty(
            startTime + period,
            withdrawAmount
        );
        
        uint256 expectedPenalty = (withdrawAmount * 5) / 100; // 5%
        assertEq(penaltyAmount, expectedPenalty);
        
        // Check max withdraw amount
        uint256 maxWithdraw = stakingContract.getUserMaxUrgentWithdraw(user1);
        uint256 expectedMaxWithdraw = (stakeAmount * 95) / 100; // 95% of stake amount (5% penalty)
        assertEq(maxWithdraw, expectedMaxWithdraw);
        
        // Test actual withdraw
        uint256 initialBalance = stakingToken.balanceOf(user1);
        
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(withdrawAmount);
        vm.stopPrank();
        
        // Check balance update
        assertEq(stakingToken.balanceOf(user1), initialBalance + withdrawAmount);
        
        // Check stake reduction (should be reduced by withdraw + penalty)
        (uint256 remainingStake,,) = stakingContract.userStake(user1);
        assertEq(remainingStake, stakeAmount - withdrawAmount - expectedPenalty);
        
        // Check penalty locked amount
        assertEq(stakingContract.getPenaltyLockedAmount(), expectedPenalty);
    }
    
    function testPenaltyRate30To59Days() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        approveAndStake(user1, stakeAmount, 2); // 90 days
        
        // Advance time to have exactly 45 days left
        warpForward(90 days - 45 days);
        
        // Check penalty preview (should be 10% since 30-59 days left)
        (,uint256 startTime2, uint256 period2) = stakingContract.userStake(user1);
        uint256 penaltyAmount = stakingContract.previewEarlyWithdrawPenalty(
            startTime2 + period2,
            withdrawAmount
        );
        
        uint256 expectedPenalty = (withdrawAmount * 10) / 100; // 10%
        assertEq(penaltyAmount, expectedPenalty);
        
        // Check max withdraw amount
        uint256 maxWithdraw = stakingContract.getUserMaxUrgentWithdraw(user1);
        uint256 expectedMaxWithdraw = (stakeAmount * 90) / 100; // 90% of stake amount (10% penalty)
        assertEq(maxWithdraw, expectedMaxWithdraw);
    }
    
    function testPenaltyRate60To89Days() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        approveAndStake(user1, stakeAmount, 2); // 90 days
        
        // Advance time to have exactly 75 days left
        warpForward(90 days - 75 days);
        
        // Check penalty preview (should be 15% since 60-89 days left)
        (,uint256 startTime3, uint256 period3) = stakingContract.userStake(user1);
        uint256 penaltyAmount = stakingContract.previewEarlyWithdrawPenalty(
            startTime3 + period3,
            withdrawAmount
        );
        
        uint256 expectedPenalty = (withdrawAmount * 15) / 100; // 15%
        assertEq(penaltyAmount, expectedPenalty);
        
        // Check max withdraw amount
        uint256 maxWithdraw = stakingContract.getUserMaxUrgentWithdraw(user1);
        uint256 expectedMaxWithdraw = (stakeAmount * 85) / 100; // 85% of stake amount (15% penalty)
        assertEq(maxWithdraw, expectedMaxWithdraw);
    }
    
    function testPenaltyRateOver90Days() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        
        // Create a custom staking period for this test
        uint256[] memory longPeriods = new uint256[](1);
        longPeriods[0] = 200 days;
        
        // Deploy a new contract with longer staking period
        TokenStaking longStakingContract = new TokenStaking(address(stakingToken), longPeriods);
        
        // Approve and stake
        vm.startPrank(user1);
        stakingToken.approve(address(longStakingContract), stakeAmount);
        longStakingContract.stake(stakeAmount, 0); // 200 days
        vm.stopPrank();
        
        // Advance time to have exactly 100 days left (still over 90)
        warpForward(100 days);
        
        // Check penalty preview (should be 20% since >= 90 days left)
        (,uint256 stakeStartTime, uint256 stakePeriod) = longStakingContract.userStake(user1);
        uint256 penaltyAmount = longStakingContract.previewEarlyWithdrawPenalty(
            stakeStartTime + stakePeriod,
            withdrawAmount
        );
        
        uint256 expectedPenalty = (withdrawAmount * 20) / 100; // 20%
        assertEq(penaltyAmount, expectedPenalty);
        
        // Check max withdraw amount
        uint256 maxWithdraw = longStakingContract.getUserMaxUrgentWithdraw(user1);
        uint256 expectedMaxWithdraw = (stakeAmount * 80) / 100; // 80% of stake amount (20% penalty)
        assertEq(maxWithdraw, expectedMaxWithdraw);
    }
    
    function testUrgentWithdrawWithComplexAmounts() public {
        // Test with a non-round number to check for rounding issues
        uint256 stakeAmount = 1777 * 10**18;
        uint256 withdrawAmount = 423 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        // Calculate expected penalty (10% for 30 days period)
        uint256 expectedPenalty = (withdrawAmount * 10) / 100;
        
        // Initial state check
        uint256 initialBalance = stakingToken.balanceOf(user1);
        uint256 initialPenaltyLocked = stakingContract.getPenaltyLockedAmount();
        
        // Perform urgent withdraw
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(withdrawAmount);
        vm.stopPrank();
        
        // Verify balances
        assertEq(stakingToken.balanceOf(user1), initialBalance + withdrawAmount);
        
        // Verify remaining stake (should be reduced by withdraw amount + penalty)
        (uint256 remainingStake,,) = stakingContract.userStake(user1);
        assertEq(remainingStake, stakeAmount - withdrawAmount - expectedPenalty);
        
        // Verify penalty locked amount is increased correctly
        assertEq(stakingContract.getPenaltyLockedAmount(), initialPenaltyLocked + expectedPenalty);
    }
    
    function testPenaltyAccumulation() public {
        // Let's have two users make urgent withdrawals and check the accumulated penalties
        uint256 user1StakeAmount = 1000 * 10**18;
        uint256 user2StakeAmount = 2000 * 10**18;
        
        uint256 user1WithdrawAmount = 400 * 10**18;
        uint256 user2WithdrawAmount = 800 * 10**18;
        
        // User 1 stakes for 30 days
        approveAndStake(user1, user1StakeAmount, 1);
        
        // User 2 stakes for 90 days
        approveAndStake(user2, user2StakeAmount, 2);
        
        // Forward time to have 25 days left for user 1 (5% penalty)
        // and 85 days left for user 2 (15% penalty)
        warpForward(5 days);
        
        // User 1 makes an urgent withdraw
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(user1WithdrawAmount);
        vm.stopPrank();
        
        // User 2 makes an urgent withdraw
        vm.startPrank(user2);
        stakingContract.urgentWithdraw(user2WithdrawAmount);
        vm.stopPrank();
        
        // Calculate expected penalties
        uint256 user1Penalty = (user1WithdrawAmount * 5) / 100;
        uint256 user2Penalty = (user2WithdrawAmount * 15) / 100;
        uint256 totalExpectedPenalty = user1Penalty + user2Penalty;
        
        // Check accumulated penalty
        assertEq(stakingContract.getPenaltyLockedAmount(), totalExpectedPenalty);
        
        // Now test owner withdrawing the penalties
        uint256 ownerInitialBalance = stakingToken.balanceOf(address(this));
        
        vm.startPrank(address(this));
        stakingContract.withdrawPenaltyLockedAmount();
        vm.stopPrank();
        
        // Check owner received the penalty tokens
        assertEq(stakingToken.balanceOf(address(this)), ownerInitialBalance + totalExpectedPenalty);
        
        // Check penalty locked amount is reset to zero
        assertEq(stakingContract.getPenaltyLockedAmount(), 0);
    }
    
    function testGetUserMaxUrgentWithdraw() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        // For 30 days staking period, the penalty should be 10%
        uint256 expectedMaxWithdraw = (stakeAmount * 90) / 100; // 90% of stake
        
        uint256 maxWithdraw = stakingContract.getUserMaxUrgentWithdraw(user1);
        assertEq(maxWithdraw, expectedMaxWithdraw);
    }
    
    function testWithdrawPenaltyLockedAmount() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        // Perform urgent withdraw to accumulate penalty
        uint256 withdrawAmount = 500 * 10**18;
        
        vm.startPrank(user1);
        stakingContract.urgentWithdraw(withdrawAmount);
        vm.stopPrank();
        
        // Calculate expected penalty (10% for 30 days)
        uint256 expectedPenalty = (withdrawAmount * 10) / 100;
        
        // Verify penalty accumulation
        assertEq(stakingContract.getPenaltyLockedAmount(), expectedPenalty);
        
        // Test owner withdrawing the penalty
        uint256 ownerInitialBalance = stakingToken.balanceOf(address(this));
        
        vm.startPrank(address(this));
        stakingContract.withdrawPenaltyLockedAmount();
        vm.stopPrank();
        
        // Verify owner received funds and contract penalty is reset
        assertEq(stakingToken.balanceOf(address(this)), ownerInitialBalance + expectedPenalty);
        assertEq(stakingContract.getPenaltyLockedAmount(), 0);
        
        // Try to withdraw again when penalty is 0
        vm.startPrank(address(this));
        vm.expectRevert("No penalty locked amount");
        stakingContract.withdrawPenaltyLockedAmount();
        vm.stopPrank();
    }
    
    function testOnlyOwnerCanWithdrawPenalty() public {
        vm.startPrank(user1);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", user1));
        stakingContract.withdrawPenaltyLockedAmount();
        vm.stopPrank();
    }
    
    // --- Add to Existing Stake Tests ---
    function testAddToExistingStake() public {
        uint256 initialStake = 1000 * 10**18;
        uint256 additionalStake = 500 * 10**18;
        uint256 periodIndex = 1; // 30 days
        
        // Initial stake
        approveAndStake(user1, initialStake, periodIndex);
        
        // Add to existing stake
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), additionalStake);
        stakingContract.stake(additionalStake, periodIndex);
        vm.stopPrank();
        
        // Check total stake
        (uint256 totalAmount,,) = stakingContract.userStake(user1);
        assertEq(totalAmount, initialStake + additionalStake);
    }
    
    // --- Event Emission Tests ---
    function testStakeEventEmission() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 periodIndex = 0; // 7 days
        
        vm.startPrank(user1);
        stakingToken.approve(address(stakingContract), stakeAmount);
        
        vm.expectEmit(true, true, false, true);
        emit Staked(user1, stakeAmount, stakingPeriods[periodIndex], block.timestamp, block.timestamp + stakingPeriods[periodIndex]);
        stakingContract.stake(stakeAmount, periodIndex);
        vm.stopPrank();
    }
    
    function testWithdrawEventEmission() public {
        uint256 stakeAmount = 1000 * 10**18;
        approveAndStake(user1, stakeAmount, 0); // 7 days
        
        // Warp past staking period
        warpForward(7 days + 1);
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(user1, stakeAmount, block.timestamp);
        stakingContract.withdraw();
        vm.stopPrank();
    }
    
    function testUrgentWithdrawEventEmission() public {
        uint256 stakeAmount = 1000 * 10**18;
        uint256 withdrawAmount = 500 * 10**18;
        approveAndStake(user1, stakeAmount, 1); // 30 days
        
        // Calculate expected penalty (10% for 30 days)
        uint256 expectedPenalty = (withdrawAmount * 10) / 100;
        
        vm.startPrank(user1);
        vm.expectEmit(true, true, true, true);
        emit UrgentWithdrawn(user1, withdrawAmount, expectedPenalty, block.timestamp);
        stakingContract.urgentWithdraw(withdrawAmount);
        vm.stopPrank();
    }
    
    // --- Custom Events for Testing ---
    event Staked(address indexed user, uint256 amount, uint256 period, uint256 startTime, uint256 endTime);
    event Withdrawn(address indexed user, uint256 amount, uint256 timestamp);
    event UrgentWithdrawn(address indexed user, uint256 amount, uint256 penalty, uint256 timestamp);
}
