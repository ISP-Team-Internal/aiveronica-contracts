// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract TokenStaking is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants for security improvement
    uint256 public constant MAX_STAKES_PER_USER = 10;
    uint256 public constant MIN_STAKE_AMOUNT_FACTOR = 1e12; // 1e-6 of tokens (assuming 18 decimals)

    IERC20 public immutable stakingToken;
    uint256[] public stakingPeriods; // Array of available staking periods

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 period; // Chosen staking period for this stake
        bool withdrawn;
    }

    mapping(address => Stake[]) public userStakes;
    mapping(address => uint256) public activeStakeCount;

    // Enhanced events with more data and indexing
    event Staked(address indexed user, uint256 indexed stakeIndex, uint256 amount, uint256 period, uint256 startTime, uint256 endTime);
    event Withdrawn(address indexed user, uint256 indexed stakeIndex, uint256 amount, uint256 stakedFor);
    event StakeReplaced(address indexed user, uint256 indexed stakeIndex, uint256 oldAmount, uint256 newAmount);

    constructor(address _stakingToken, uint256[] memory _stakingPeriods) {
        require(_stakingToken != address(0), "Invalid token address");
        require(_stakingPeriods.length > 0, "Must provide at least one staking period");
        for (uint256 i = 0; i < _stakingPeriods.length; i++) {
            require(_stakingPeriods[i] > 0, "Staking period must be greater than 0");
            stakingPeriods.push(_stakingPeriods[i]);
        }
        stakingToken = IERC20(_stakingToken);
    }

    function getStakingPeriods() external view returns (uint256[] memory) {
        return stakingPeriods;
    }

    /**
     * @notice Stake tokens for a specific period
     * @param _amount Amount of tokens to stake
     * @param _periodIndex Index of the staking period
     * @return stakeIndex The index of the stake that was created or replaced
     * @return isNewStake Whether a new stake was created or an existing one was replaced
     */
    function stake(uint256 _amount, uint256 _periodIndex) external nonReentrant returns (uint256 stakeIndex, bool isNewStake) {
        require(_amount > 0, "Amount must be greater than 0");
        require(_amount >= MIN_STAKE_AMOUNT_FACTOR, "Amount below minimum stake threshold");
        require(_periodIndex < stakingPeriods.length, "Invalid period index");

        uint256 chosenPeriod = stakingPeriods[_periodIndex];

        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        Stake memory newStake = Stake({
            amount: _amount,
            startTime: block.timestamp,
            period: chosenPeriod,
            withdrawn: false
        });

        // Check if we can replace a withdrawn stake
        for (uint256 i = 0; i < userStakes[msg.sender].length; i++) {
            if (userStakes[msg.sender][i].withdrawn) {
                uint256 oldAmount = userStakes[msg.sender][i].amount;
                userStakes[msg.sender][i] = newStake;
                emit StakeReplaced(msg.sender, i, oldAmount, _amount);
                activeStakeCount[msg.sender]++;
                
                // Return the replaced stake index
                return (i, false);
            }
        }

        // Check if max stakes limit is reached
        require(
            activeStakeCount[msg.sender] < MAX_STAKES_PER_USER,
            "Maximum active stakes reached"
        );

        // Create a new stake
        userStakes[msg.sender].push(newStake);
        activeStakeCount[msg.sender]++;
        
        // Calculate end time for the event
        uint256 endTime = block.timestamp + chosenPeriod;
        
        // Emit enhanced stake event
        emit Staked(
            msg.sender, 
            userStakes[msg.sender].length - 1, 
            _amount, 
            chosenPeriod, 
            block.timestamp, 
            endTime
        );
        
        // Return the new stake index
        return (userStakes[msg.sender].length - 1, true);
    }

    /**
     * @notice Withdraw tokens from a stake after lock period
     * @param _stakeIndex Index of the stake to withdraw
     * @return success Whether the withdrawal was successful
     * @return amount Amount of tokens withdrawn
     */
    function withdraw(uint256 _stakeIndex) external nonReentrant returns (bool success, uint256 amount) {
        require(_stakeIndex < userStakes[msg.sender].length, "Invalid stake index");

        Stake storage stake = userStakes[msg.sender][_stakeIndex];
        require(!stake.withdrawn, "Already withdrawn");
        require(block.timestamp >= stake.startTime + stake.period, "Lock period not ended");

        amount = stake.amount;
        uint256 stakedFor = block.timestamp - stake.startTime;
        
        stake.withdrawn = true;
        activeStakeCount[msg.sender]--;

        stakingToken.safeTransfer(msg.sender, amount);

        // Emit enhanced withdrawal event
        emit Withdrawn(msg.sender, _stakeIndex, amount, stakedFor);
        
        return (true, amount);
    }

    function getStakeInfo(address _user, uint256 _stakeIndex) 
        external 
        view 
        returns (
            uint256 amount,
            uint256 startTime,
            uint256 period,
            bool withdrawn,
            uint256 timeLeft
        ) 
    {
        require(_stakeIndex < userStakes[_user].length, "Invalid stake index");

        Stake memory stake = userStakes[_user][_stakeIndex];
        uint256 endTime = stake.startTime + stake.period;
        uint256 remainingTime = block.timestamp >= endTime ? 0 : endTime - block.timestamp;

        return (
            stake.amount,
            stake.startTime,
            stake.period,
            stake.withdrawn,
            remainingTime
        );
    }

    function getStakeCount(address _user) external view returns (uint256) {
        return userStakes[_user].length;
    }
    
    function getActiveStakeCount(address _user) external view returns (uint256) {
        return activeStakeCount[_user];
    }
}