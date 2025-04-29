// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DepositThresholdNFT
 * @dev An ERC721 contract for a whitelist campaign with ERC20 token deposits, admin withdrawals, and daily limits.
 */
contract DepositThresholdNFT is ERC721, Ownable, ReentrancyGuard, Pausable {
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
    mapping(address => bool) public hasPurchased; // Tracks whether a user has ever purchased

    string private _baseTokenURI; // Base URI for token metadata

    event MintedNFT(
        address indexed user,
        uint256 tokenId,
        uint256 amount,
        uint256 day
    );
    event AdminWithdrawal(uint256 amount, address indexed to);
    event EmergencyWithdrawal(
        address indexed token,
        uint256 amount,
        address indexed to
    );
    event CampaignInitialized(
        uint256 startingTimestamp,
        address token,
        uint256[] dailyTokenAmounts,
        uint256[] dailyWhitelistLimits,
        uint256 campaignDuration,
        address initialOwner
    );

    constructor(
        uint256 _startingTimestamp,
        address _tokenAddress,
        uint256[] memory _dailyTokenAmounts,
        uint256[] memory _dailyWhitelistLimits,
        uint256 _campaignDuration,
        address _initialOwner,
        string memory baseTokenURI
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
        require(_initialOwner != address(0), "Invalid initial owner address");

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
        _baseTokenURI = baseTokenURI;

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
            _campaignDuration,
            _initialOwner
        );
    }

    // --- Admin Functions ---

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

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

    /**
     * @dev Allows the owner to withdraw all campaign tokens to their own address
     */
    function adminWithdrawAll() external nonReentrant onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        token.safeTransfer(owner(), balance);
        emit AdminWithdrawal(balance, owner());
    }

    /**
     * @dev Allows the owner to withdraw any ETH that might be accidentally sent to the contract
     */
    function withdrawETH(address payable _to) external nonReentrant onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH balance to withdraw");
        (bool success, ) = _to.call{value: balance}("");
        require(success, "ETH transfer failed");
        emit EmergencyWithdrawal(address(0), balance, _to);
    }

    /**
     * @dev Allows the owner to withdraw any ERC20 tokens that might be accidentally sent to the contract
     * @param _token The address of the ERC20 token to withdraw
     * @param _to The address to send the tokens to
     */
    function withdrawERC20(
        IERC20 _token,
        address _to
    ) external nonReentrant onlyOwner {
        require(_to != address(0), "Invalid recipient address");
        require(
            address(_token) != address(token),
            "Use adminWithdraw for campaign token"
        );
        uint256 balance = _token.balanceOf(address(this));
        require(balance > 0, "No token balance to withdraw");
        _token.safeTransfer(_to, balance);
        emit EmergencyWithdrawal(address(_token), balance, _to);
    }

    // --- User Functions ---

    /**
     * @dev Mints an NFT by depositing the required ERC20 tokens for the current day.
     *      Reverts if the daily whitelist limit is reached or if the user has already minted today.
     */
    function mint() external nonReentrant whenNotPaused {
        uint256 currentDay = getCurrentDay();
        require(
            currentDay != type(uint256).max,
            "Campaign is not active or has ended"
        );
        require(
            dailyWhitelistCount[currentDay] < dailyWhitelistLimits[currentDay],
            "Daily whitelist limit reached"
        );
        require(
            !hasPurchased[msg.sender] ||
                lastPurchaseDay[msg.sender] != currentDay,
            "Already purchased today"
        );

        uint256 requiredAmount = getRequiredDepositAmount(currentDay);
        require(
            token.balanceOf(msg.sender) >= requiredAmount,
            "Insufficient token balance"
        );
        require(
            token.allowance(msg.sender, address(this)) >= requiredAmount,
            "Insufficient token allowance. Please approve the contract to spend your tokens first"
        );
        // Store the next token ID
        uint256 tokenId = _tokenIdCounter;

        // Update all contract state before external interactions
        _tokenIdCounter += 1;
        dailyWhitelistCount[currentDay] += 1;
        lastPurchaseDay[msg.sender] = currentDay; // Record the purchase day
        hasPurchased[msg.sender] = true; // Mark user as having purchased

        // External interactions last
        token.safeTransferFrom(msg.sender, address(this), requiredAmount);
        _safeMint(msg.sender, tokenId);

        emit MintedNFT(msg.sender, tokenId, requiredAmount, currentDay);
    }

    /**
     * @dev Get the current day of the campaign (0-based index).
     * @return uint256 The current day (0 to numDays-1) or type(uint256).max if before campaign start or after campaign end.
     */
    function getCurrentDay() public view returns (uint256) {
        if (block.timestamp < startingTimestamp) {
            return type(uint256).max;
        }
        uint256 day = (block.timestamp - startingTimestamp) / SECONDS_PER_DAY;
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        return day < totalDays ? day : type(uint256).max;
    }

    /**
     * @dev Calculate the required deposit amount for a given day.
     * @param _day The day of the campaign (0 to numDays-1).
     * @return uint256 The required deposit amount.
     */
    function getRequiredDepositAmount(
        uint256 _day
    ) public view returns (uint256) {
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        require(_day < totalDays, "Invalid day");
        return dailyTokenAmounts[_day];
    }

    /**
     * @dev Get the remaining whitelists available for the current day.
     * @return uint256 The number of remaining whitelists.
     */
    function getRemainingWhitelistsToday() public view returns (uint256) {
        uint256 currentDay = getCurrentDay();
        uint256 totalDays = campaignDuration / SECONDS_PER_DAY;
        if (currentDay == type(uint256).max || currentDay >= totalDays) {
            return 0;
        }
        return
            dailyWhitelistLimits[currentDay] - dailyWhitelistCount[currentDay];
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

    /**
     * @dev Returns the base URI for token metadata
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Returns the URI for a given token ID
     */
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string(abi.encodePacked(_baseURI(), Strings.toString(tokenId)));
    }

    /**
     * @dev Allows the owner to update the base URI for token metadata
     */
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }
}
