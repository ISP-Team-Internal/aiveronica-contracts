// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/**
 * @title DepositThresholdNFT
 * @dev An ERC721 contract for a whitelist campaign with ERC20 token deposits, admin withdrawals, and daily limits.
 */
contract DepositThresholdNFT is ERC721, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token; // ERC20 token address
    uint256 public immutable startingTimestamp; // Start timestamp of the campaign
    uint256 public immutable campaignDuration; // Duration of the campaign in seconds
    uint256[] public dailyTokenAmounts; // Array of token amounts required for each day
    uint256[] public dailyWhitelistLimits; // Array of whitelist limits for each day
    uint256 private _tokenIdCounter; // Counter for token IDs

    uint256 constant SECONDS_PER_DAY = 1 days; // For day calculations

    mapping(uint256 => uint256) public dailyWhitelistCount; // Tracks whitelist count per day
    mapping(address => uint256) public lastPurchaseDay; // Tracks the last day a user made a purchase

    event MintedNFT(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 day
    );
    event AdminWithdrawal(uint256 amount, address indexed to);
    event CampaignInitialized(
        uint256 startingTimestamp,
        address token,
        uint256[] dailyTokenAmounts,
        uint256[] dailyWhitelistLimits,
        uint256 campaignDuration
    );

    constructor(
        uint256 _startingTimestamp,
        address _tokenAddress,
        uint256[] memory _dailyTokenAmounts,
        uint256[] memory _dailyWhitelistLimits,
        uint256 _campaignDuration,
        address _initialOwner
    ) ERC721("DepositThresholdNFT", "DTNFT") Ownable(_initialOwner) {
        require(
            _startingTimestamp > block.timestamp,
            "Starting timestamp must be in the future"
        );
        require(_tokenAddress != address(0), "Invalid token address");
        require(
            _campaignDuration > 0,
            "Campaign duration must be greater than 0"
        );
        require(
            _dailyTokenAmounts.length == _campaignDuration / SECONDS_PER_DAY,
            "Token amounts length must match campaign duration in days"
        );
        require(
            _dailyWhitelistLimits.length == _campaignDuration / SECONDS_PER_DAY,
            "Whitelist limits length must match campaign duration in days"
        );

        // Validate that all daily amounts and limits are greater than 0
        for (uint256 i = 0; i < _dailyTokenAmounts.length; i++) {
            require(
                _dailyTokenAmounts[i] > 0,
                "Daily token amount must be greater than 0"
            );
            require(
                _dailyWhitelistLimits[i] > 0,
                "Daily whitelist limit must be greater than 0"
            );
        }
        require(
            _campaignDuration % SECONDS_PER_DAY == 0,
            "Campaign duration must be multiple of one day"
        );
        startingTimestamp = _startingTimestamp;
        token = IERC20(_tokenAddress);
        campaignDuration = _campaignDuration;
        _tokenIdCounter = 1; // Start token IDs from 1

        // Store daily amounts and limits
        for (uint256 i = 0; i < _dailyTokenAmounts.length; i++) {
            dailyTokenAmounts.push(_dailyTokenAmounts[i]);
            dailyWhitelistLimits.push(_dailyWhitelistLimits[i]);
        }

        emit CampaignInitialized(
            _startingTimestamp,
            _tokenAddress,
            _dailyTokenAmounts,
            _dailyWhitelistLimits,
            _campaignDuration
        );
    }

    modifier campaignActive() {
        require(block.timestamp >= startingTimestamp, "Campaign is not active");
        require(
            block.timestamp < startingTimestamp + campaignDuration,
            "Campaign has ended"
        );
        _;
    }

    // --- Admin Functions ---

    function adminWithdraw(
        uint256 _amount,
        address _to
    ) external nonReentrant onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(_amount > 0, "Amount must be greater than 0");
        require(
            token.balanceOf(address(this)) >= _amount,
            "Insufficient token balance"
        );
        token.safeTransfer(_to, _amount);
        emit AdminWithdrawal(_amount, _to);
    }

    // --- User Functions ---

    /**
     * @dev Mints an NFT by depositing the required ERC20 tokens for the current day.
     *      Reverts if the daily whitelist limit is reached or if the user has already minted today.
     */
    function mint() external nonReentrant campaignActive {
        uint256 currentDay = getCurrentDay();
        require(
            dailyWhitelistCount[currentDay] <
                dailyWhitelistLimits[currentDay - 1],
            "Daily whitelist limit reached"
        );
        require(
            lastPurchaseDay[msg.sender] != currentDay,
            "Already purchased today"
        );

        uint256 requiredAmount = getRequiredDepositAmount(currentDay);
        require(
            token.balanceOf(msg.sender) >= requiredAmount,
            "Insufficient token balance"
        );
        // Store the next token ID
        uint256 tokenId = _tokenIdCounter;

        // Update all contract state before external interactions
        _tokenIdCounter += 1;
        dailyWhitelistCount[currentDay] += 1;
        lastPurchaseDay[msg.sender] = currentDay; // Record the purchase day

        // External interactions last
        token.safeTransferFrom(msg.sender, address(this), requiredAmount);
        _safeMint(msg.sender, tokenId);

        emit MintedNFT(msg.sender, tokenId, requiredAmount, currentDay);
    }

    /**
     * @dev Get the current day of the campaign (1-based index).
     * @return uint256 The current day (1 to numDays) or 0 if before campaign start.
     */
    function getCurrentDay() public view returns (uint256) {
        if (block.timestamp < startingTimestamp) {
            return 0;
        }
        uint256 day = ((block.timestamp - startingTimestamp) /
            SECONDS_PER_DAY) + 1;
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        return day <= totalDays ? day : 0;
    }

    /**
     * @dev Calculate the required deposit amount for a given day.
     * @param _day The day of the campaign (1 to numDays).
     * @return uint256 The required deposit amount.
     */
    function getRequiredDepositAmount(
        uint256 _day
    ) public view returns (uint256) {
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        require(_day >= 1 && _day <= totalDays, "Invalid day");
        return dailyTokenAmounts[_day - 1];
    }

    /**
     * @dev Get the remaining whitelists available for the current day.
     * @return uint256 The number of remaining whitelists.
     */
    function getRemainingWhitelistsToday() public view returns (uint256) {
        uint256 currentDay = getCurrentDay();
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        if (currentDay < 1 || currentDay > totalDays) {
            return 0;
        }
        return
            dailyWhitelistLimits[currentDay - 1] -
            dailyWhitelistCount[currentDay];
    }

    /**
     * @dev Get the next available token ID.
     * @return uint256 The next token ID to be minted.
     */
    function getNextTokenId() public view returns (uint256) {
        return _tokenIdCounter;
    }

    /**
     * @dev Overrides transferFrom to make NFTs non-transferrable.
     */
    function transferFrom(address, address, uint256) public pure override {
        revert("DepositThresholdNFT: Tokens are non-transferrable");
    }

    /**
     * @dev Overrides safeTransferFrom with data to make NFTs non-transferrable.
     */
    function safeTransferFrom(
        address,
        address,
        uint256,
        bytes memory
    ) public pure override {
        revert("DepositThresholdNFT: Tokens are non-transferrable");
    }

    /**
     * @dev Overrides approve to prevent approvals.
     */
    function approve(address, uint256) public pure override {
        revert("DepositThresholdNFT: Approvals are disabled");
    }

    /**
     * @dev Overrides setApprovalForAll to prevent operator approvals.
     */
    function setApprovalForAll(address, bool) public pure override {
        revert("DepositThresholdNFT: Operator approvals are disabled");
    }
}
