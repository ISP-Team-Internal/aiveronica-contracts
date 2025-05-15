// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenStaking is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;

    // Constants for security improvement
    uint256 public constant MIN_STAKE_AMOUNT_FACTOR = 1e12; // 1e-6 of tokens (assuming 18 decimals)

    IERC20 public immutable stakingToken;
    uint256[] public stakingPeriods; // Array of available staking periods

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 period; // Chosen staking period for this stake
    }

    mapping(address => Stake) public userStake;

    // Enhanced events with more data and indexing
    event Staked(
        address indexed user,
        uint256 amount,
        uint256 period,
        uint256 startTime,
        uint256 endTime
    );
    event Withdrawn(address indexed user, uint256 amount);
    event StakeReplaced(
        address indexed user,
        uint256 oldAmount,
        uint256 newAmount,
        uint256 newPeriod,
        uint256 newStartTime,
        uint256 newEndTime
    );
    event StakeExtended(
        address indexed user,
        uint256 amount,
        uint256 newPeriod,
        uint256 newStartTime,
        uint256 newEndTime
    );

    constructor(
        address _stakingToken,
        uint256[] memory _stakingPeriods
    ) Ownable(msg.sender) {
        require(_stakingToken != address(0), "Invalid token address");
        require(
            _stakingPeriods.length > 0,
            "Must provide at least one staking period"
        );
        for (uint256 i = 0; i < _stakingPeriods.length; i++) {
            require(
                _stakingPeriods[i] > 0,
                "Staking period must be greater than 0"
            );
            stakingPeriods.push(_stakingPeriods[i]);
        }
        stakingToken = IERC20(_stakingToken);
    }

    // --- Admin Functions ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getStakingPeriods() external view returns (uint256[] memory) {
        return stakingPeriods;
    }

    function isStakeExpired(Stake memory _stake) internal view returns (bool) {
        return
            _stake.amount > 0 &&
            _stake.startTime + _stake.period < block.timestamp;
    }

    function isUserStakedBefore(address user) internal view returns (bool) {
        return userStake[user].amount > 0 && userStake[user].period >= 0;
    }

    /**
     * @notice Stake tokens for a specific period
     * @param _amount Amount of tokens to stake
     * @param _periodIndex Index of the staking period
     */
    function stake(
        uint256 _amount,
        uint256 _periodIndex
    ) external whenNotPaused nonReentrant {
        require(
            _amount >= MIN_STAKE_AMOUNT_FACTOR,
            "Amount below minimum stake threshold"
        );
        require(_periodIndex < stakingPeriods.length, "Invalid period index");

        uint256 chosenPeriod = stakingPeriods[_periodIndex];

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        Stake memory newStake = Stake({
            amount: _amount,
            startTime: block.timestamp,
            period: chosenPeriod
        });
        Stake storage oldStake = userStake[msg.sender];

        // * User has not staked before
        // simply create a new stake
        if (!isUserStakedBefore(msg.sender)) {
            userStake[msg.sender] = newStake;
            return;
        }
        // * User has staked before
        if (isStakeExpired(oldStake)) {
            // * check if the previous stake is withdrawn
            require(oldStake.amount == 0, "Previous stake is not withdrawn");
        } else {
            // * User has staked before and the stake is not expired
            require(
                chosenPeriod >= oldStake.period,
                "New stake period is shorter than the previous stake"
            );
            newStake.amount += oldStake.amount;
        }
        userStake[msg.sender] = newStake;
    }

    /**
     * @notice Withdraw tokens from a stake after lock period
     * @return success Whether the withdrawal was successful
     * @return amount Amount of tokens withdrawn
     */
    function withdraw()
        external
        nonReentrant
        returns (bool success, uint256 amount)
    {
        require(isUserStakedBefore(msg.sender), "User has not staked before");
        require(isStakeExpired(userStake[msg.sender]), "Stake is not expired");
        amount = userStake[msg.sender].amount;
        stakingToken.safeTransfer(msg.sender, amount);
        userStake[msg.sender].amount = 0;
        // Emit enhanced withdrawal event
        emit Withdrawn(msg.sender, amount);

        return (true, amount);
    }

    /**
     * @notice Extend the staking period
     * @param _periodIndex Index of the new staking period
     */
    function extendStaking(
        uint256 _periodIndex
    ) external whenNotPaused nonReentrant {
        require(isUserStakedBefore(msg.sender), "User has not staked before");
        Stake storage _stake = userStake[msg.sender];
        require(isStakeExpired(_stake), "Stake is not expired");
        require(_periodIndex < stakingPeriods.length, "Invalid period index");

        uint256 newPeriod = stakingPeriods[_periodIndex];

        _stake.startTime = block.timestamp;
        _stake.period = newPeriod;

        emit StakeExtended(
            msg.sender,
            _stake.amount,
            newPeriod,
            _stake.startTime,
            _stake.startTime + newPeriod
        );
    }
}
