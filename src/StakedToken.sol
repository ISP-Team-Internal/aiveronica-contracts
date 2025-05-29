// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import "@openzeppelin/contracts-upgradeable/governance/utils/VotesUpgradeable.sol";

/*
Contract fetched from https://basescan.org/address/0x785a196826b7b54c7baa0eb563739eca331b91f8#code
*/
contract stakedToken is
    Initializable,
    ReentrancyGuardUpgradeable,
    AccessControlUpgradeable,
    VotesUpgradeable
{
    using SafeERC20 for IERC20;
    struct Lock {
        uint256 amount;
        uint256 start;
        uint256 end;
        uint8 numWeeks; // Active duration in weeks. Reset to maxWeeks if autoRenew is true.
        bool autoRenew;
        uint256 id;
    }

    uint16 public constant DENOM = 10000;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    uint256 public constant MAX_POSITIONS = 200;

    address public baseToken;
    mapping(address => Lock[]) public locks;
    uint256 private _nextId;

    uint8 public maxWeeks;

    event Stake(
        address indexed user,
        uint256 id,
        uint256 amount,
        uint8 numWeeks
    );
    event Withdraw(address indexed user, uint256 id, uint256 amount);
    event Extend(address indexed user, uint256 id, uint8 numWeeks);
    event AutoRenew(address indexed user, uint256 id, bool autoRenew);

    event AdminUnlocked(bool adminUnlocked);
    bool public adminUnlocked;
    string private _name;
    string private _symbol;

    /**
     * @notice Initializes the staked token contract with base parameters
     * @dev This function replaces the constructor for upgradeable contracts. Sets up access control,
     *      reentrancy protection, voting functionality, and EIP712 domain. Grants admin roles to deployer.
     * @param baseToken_ The address of the underlying ERC20 token to be staked
     * @param maxWeeks_ Maximum number of weeks a token can be locked for
     * @param name_ The name of the staked token (used for EIP712 domain)
     * @param symbol_ The symbol of the staked token
     */
    function initialize(
        address baseToken_,
        uint8 maxWeeks_,
        string memory name_,
        string memory symbol_
    ) external initializer {
        __ReentrancyGuard_init();
        __AccessControl_init();
        __Votes_init();
        __EIP712_init(name_, "1");

        require(baseToken_ != address(0), "Invalid token");
        baseToken = baseToken_;
        maxWeeks = maxWeeks_;
        _nextId = 1;
        _name = name_;
        _symbol = symbol_;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _grantRole(ADMIN_ROLE, _msgSender());
    }

    /**
     * @notice Returns the total number of staking positions for a given account
     * @dev Simply returns the length of the locks array for the specified account
     * @param account The address to check positions for
     * @return The number of active staking positions
     */
    function numPositions(address account) public view returns (uint256) {
        return locks[account].length;
    }

    /**
     * @notice Retrieves a paginated list of staking positions for an account
     * @dev Returns a subset of locks starting from 'start' index with 'count' items.
     *      Useful for frontend pagination when an account has many positions.
     * @param account The address to get positions for
     * @param start The starting index in the locks array
     * @param count The maximum number of positions to return
     * @return results Array of Lock structs containing position details
     */
    function getPositions(
        address account,
        uint256 start,
        uint256 count
    ) public view returns (Lock[] memory) {
        Lock[] memory results = new Lock[](count);
        uint j = 0;
        for (
            uint i = start;
            i < (start + count) && i < locks[account].length;
            i++
        ) {
            results[j] = locks[account][i];
            j++;
        }
        return results;
    }

    /**
     * @notice Calculates the voting power balance of an account at a specific timestamp
     * @dev Iterates through all locks for an account and sums their voting power at the given timestamp.
     *      For expired locks or timestamps before lock creation, returns 0. Auto-renewing locks
     *      maintain constant voting power. Non-auto-renewing locks decay linearly over time.
     * @param account The address to check balance for
     * @param timestamp The specific point in time to calculate balance for
     * @return The total voting power balance at the specified timestamp
     */
    function balanceOfAt(
        address account,
        uint256 timestamp
    ) public view returns (uint256) {
        uint256 balance = 0;
        for (uint i = 0; i < locks[account].length; i++) {
            balance += _balanceOfLockAt(locks[account][i], timestamp);
        }
        return balance;
    }

    /**
     * @notice Returns the current voting power balance of an account
     * @dev Convenience function that calls balanceOfAt with the current block timestamp
     * @param account The address to check balance for
     * @return The current total voting power balance
     */
    function balanceOf(address account) public view returns (uint256) {
        return balanceOfAt(account, block.timestamp);
    }

    /**
     * @notice Returns the current voting power of a specific lock position
     * @dev Gets the voting power of a single lock at the current timestamp
     * @param account The address that owns the lock
     * @param index The index of the lock in the account's locks array
     * @return The current voting power of the specified lock
     */
    function balanceOfLock(
        address account,
        uint256 index
    ) public view returns (uint256) {
        return _balanceOfLock(locks[account][index]);
    }

    /**
     * @notice Internal function to calculate voting power of a lock at a specific timestamp
     * @dev Core logic for voting power calculation. Auto-renewing locks maintain constant voting power
     *      equal to their calculated value. Non-auto-renewing locks decay linearly from their calculated
     *      value to 0 over the lock duration. Returns 0 if timestamp is outside the lock period.
     * @param lock The lock struct to calculate voting power for
     * @param timestamp The timestamp to calculate voting power at
     * @return The voting power of the lock at the specified timestamp
     */
    function _balanceOfLockAt(
        Lock memory lock,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 value = _calcValue(
            lock.amount,
            lock.autoRenew ? maxWeeks : lock.numWeeks
        );

        if (lock.autoRenew) {
            return value;
        }

        if (timestamp < lock.start || timestamp >= lock.end) {
            return 0;
        }

        uint256 duration = lock.end - lock.start;
        uint256 elapsed = timestamp - lock.start;
        uint256 decayRate = (value * DENOM) / duration;

        return value - (elapsed * decayRate) / DENOM;
    }

    /**
     * @notice Internal function to get current voting power of a lock
     * @dev Convenience wrapper around _balanceOfLockAt using current block timestamp
     * @param lock The lock struct to calculate voting power for
     * @return The current voting power of the lock
     */
    function _balanceOfLock(Lock memory lock) internal view returns (uint256) {
        return _balanceOfLockAt(lock, block.timestamp);
    }

    /**
     * @notice Stakes tokens with maximum duration and auto-renewal enabled
     * @dev Creates a new staking position with maxWeeks duration and auto-renewal enabled.
     *      Transfers tokens from user to contract, creates lock entry, emits event, and
     *      updates voting power. Enforces maximum position limit per user.
     * @param amount The amount of base tokens to stake
     */
    function stake(
        uint256 amount
    ) external nonReentrant {
        require(amount > 0, "Amount must be greater than 0");
        require(
            locks[_msgSender()].length < MAX_POSITIONS,
            "Over max positions"
        );

        IERC20(baseToken).safeTransferFrom(_msgSender(), address(this), amount);

        bool autoRenew = true;
        uint8 numWeeks = maxWeeks;

        uint256 end = block.timestamp + uint256(numWeeks) * 1 weeks;

        Lock memory lock = Lock({
            amount: amount,
            start: block.timestamp,
            end: end,
            numWeeks: numWeeks,
            autoRenew: autoRenew,
            id: _nextId++
        });
        locks[_msgSender()].push(lock);
        emit Stake(_msgSender(), lock.id, amount, numWeeks);
        _transferVotingUnits(address(0), _msgSender(), amount);
    }

    /**
     * @notice Calculates the voting power multiplier based on lock duration
     * @dev Determines voting power as a proportion of the staked amount based on lock duration.
     *      Locks with duration >= maxWeeks get full voting power (100%). Shorter locks get
     *      proportionally less voting power (duration/maxWeeks * 100%).
     * @param amount The base amount of tokens staked
     * @param numWeeks The duration of the lock in weeks
     * @return The calculated voting power value
     */
    function _calcValue(
        uint256 amount,
        uint8 numWeeks
    ) internal view returns (uint256) {
        return
            (amount *
                (
                    numWeeks >= maxWeeks
                        ? DENOM
                        : (uint256(numWeeks) * DENOM) / maxWeeks
                )) / DENOM;
    }

    /**
     * @notice Finds the array index of a lock by its unique ID
     * @dev Iterates through an account's locks array to find the index of a lock with the given ID.
     *      Reverts if no lock with the specified ID is found.
     * @param account The address that owns the lock
     * @param id The unique identifier of the lock to find
     * @return The index of the lock in the account's locks array
     */
    function _indexOf(
        address account,
        uint256 id
    ) internal view returns (uint256) {
        for (uint i = 0; i < locks[account].length; i++) {
            if (locks[account][i].id == id) {
                return i;
            }
        }
        revert("Lock not found");
    }

    /**
     * @notice Withdraws tokens from an expired or admin-unlocked staking position
     * @dev Allows withdrawal of staked tokens when the lock has expired or admin has enabled
     *      emergency unlocking. Cannot withdraw from auto-renewing locks. Removes the lock
     *      from the array, transfers tokens back to user, and updates voting power.
     * @param id The unique identifier of the lock to withdraw from
     */
    function withdraw(uint256 id) external nonReentrant {
        address account = _msgSender();
        uint256 index = _indexOf(account, id);
        Lock memory lock = locks[account][index];
        require(
            block.timestamp >= lock.end || adminUnlocked,
            "Lock is not expired"
        );
        require(lock.autoRenew == false, "Lock is auto-renewing");

        uint256 amount = lock.amount;

        uint256 lastIndex = locks[account].length - 1;
        if (index != lastIndex) {
            locks[account][index] = locks[account][lastIndex];
        }
        locks[account].pop();

        IERC20(baseToken).safeTransfer(account, amount);
        emit Withdraw(account, id, amount);
        _transferVotingUnits(account, address(0), amount);
    }

    /**
     * @notice Toggles the auto-renewal setting for a staking position
     * @dev Switches a lock between auto-renewing and fixed-duration modes. When toggled,
     *      resets the lock duration to maxWeeks, updates start time to current timestamp,
     *      and recalculates the end time. This effectively "restarts" the lock period.
     * @param id The unique identifier of the lock to toggle auto-renewal for
     */
    function toggleAutoRenew(uint256 id) external nonReentrant {
        address account = _msgSender();
        uint256 index = _indexOf(account, id);

        Lock storage lock = locks[account][index];
        lock.autoRenew = !lock.autoRenew;
        lock.numWeeks = maxWeeks;
        lock.start = block.timestamp;
        lock.end = block.timestamp + uint(lock.numWeeks) * 1 weeks;

        emit AutoRenew(account, id, lock.autoRenew);
    }

    /**
     * @notice Extends the duration of a non-auto-renewing staking position
     * @dev Adds additional weeks to an existing lock's duration. Only works on non-auto-renewing
     *      locks that haven't expired yet. The total duration cannot exceed maxWeeks.
     *      Updates both the numWeeks and end timestamp of the lock.
     * @param id The unique identifier of the lock to extend
     * @param numWeeks The number of additional weeks to add to the lock duration
     */
    function extend(uint256 id, uint8 numWeeks) external nonReentrant {
        address account = _msgSender();
        uint256 index = _indexOf(account, id);
        Lock storage lock = locks[account][index];
        require(lock.autoRenew == false, "Lock is auto-renewing");
        require(block.timestamp < lock.end, "Lock is expired");
        require(
            (lock.numWeeks + numWeeks) <= maxWeeks,
            "Num weeks must be less than max weeks"
        );
        uint256 newEnd = lock.end + uint256(numWeeks) * 1 weeks;

        lock.numWeeks += numWeeks;
        lock.end = newEnd;

        emit Extend(account, id, numWeeks);
    }

    /**
     * @notice Updates the maximum lock duration allowed for new stakes
     * @dev Admin-only function to change the maximum number of weeks tokens can be locked.
     *      This affects voting power calculations and the duration of new stakes.
     * @param maxWeeks_ The new maximum lock duration in weeks
     */
    function setMaxWeeks(uint8 maxWeeks_) external onlyRole(ADMIN_ROLE) {
        maxWeeks = maxWeeks_;
    }

    /**
     * @notice Returns the maturity timestamp for a specific lock
     * @dev For auto-renewing locks, returns the current timestamp plus maxWeeks (since they
     *      continuously renew). For fixed-duration locks, returns the actual end timestamp.
     * @param account The address that owns the lock
     * @param id The unique identifier of the lock
     * @return The timestamp when the lock will mature/expire
     */
    function getMaturity(
        address account,
        uint256 id
    ) public view returns (uint256) {
        uint256 index = _indexOf(account, id);
        Lock memory lock = locks[account][index];
        if (!lock.autoRenew) {
            return locks[account][index].end;
        }

        return block.timestamp + maxWeeks * 1 weeks;
    }

    /**
     * @notice Returns the name of the staked token
     * @dev Returns the human-readable name set during initialization
     * @return The name string of the staked token
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @notice Returns the symbol of the staked token
     * @dev Returns the ticker symbol set during initialization
     * @return The symbol string of the staked token
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @notice Returns the number of decimals for the staked token
     * @dev Fixed at 18 decimals to match most ERC20 tokens
     * @return The number of decimals (always 18)
     */
    function decimals() public pure returns (uint8) {
        return 18;
    }

    /**
     * @notice Enables or disables emergency withdrawal for all locks
     * @dev Admin-only function that allows users to withdraw from any lock regardless
     *      of expiration status when enabled. Used for emergency situations.
     * @param adminUnlocked_ True to enable emergency withdrawals, false to disable
     */
    function setAdminUnlocked(
        bool adminUnlocked_
    ) external onlyRole(ADMIN_ROLE) {
        adminUnlocked = adminUnlocked_;
        emit AdminUnlocked(adminUnlocked);
    }

    /**
     * @notice Internal function to get voting units for governance
     * @dev Override from VotesUpgradeable. Returns the total staked amount rather than
     *      voting power balance, ensuring voting power is based on actual tokens staked.
     * @param account The address to get voting units for
     * @return The total amount of tokens staked by the account
     */
    function _getVotingUnits(
        address account
    ) internal view virtual override returns (uint256) {
        return stakedAmountOf(account);
    }

    /**
     * @notice Returns the total amount of tokens staked by an account
     * @dev Sums up the base token amounts across all of an account's staking positions.
     *      This represents the actual tokens staked, not the voting power.
     * @param account The address to check staked amount for
     * @return The total amount of base tokens staked
     */
    function stakedAmountOf(address account) public view returns (uint256) {
        uint256 amount = 0;
        for (uint i = 0; i < locks[account].length; i++) {
            amount += locks[account][i].amount;
        }
        return amount;
    }
}