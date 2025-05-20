// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITokenStaking {
    // Events
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 period,
        uint256 actionTimestamp,
        uint256 endTime
    );
    event Withdrawn(address indexed user, uint256 amount, uint256 actionTimestamp);
    event UrgentWithdrawn(
        address indexed user,
        uint256 withdrawAmount,
        uint256 penaltyAmount,
        uint256 actionTimestamp
    );

    // View functions
    function stakingToken() external view returns (IERC20);
    function userStake(address user) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 period
    );
    function getStakingPeriods() external view returns (uint256[] memory);
    function getPenaltyLockedAmount() external view returns (uint256);
    function previewEarlyWithdrawPenalty(uint256 stakedAmount, uint256 unlocksAt, uint256 period, uint256 amountToWithdraw ) external pure returns (uint256 penaltyAmount);

    // State changing functions
    function stake(uint256 _amount, uint256 _periodIndex) external;
    function withdraw() external returns (bool success, uint256 amount);
    function extendStaking(uint256 _periodIndex) external;
    function urgentWithdraw(uint256 _amountActuallyWithdrawn) external;

    // Admin functions
    function pauseStaking() external;
    function unpauseStaking() external;
    function withdrawPenaltyLockedAmount() external;
}
