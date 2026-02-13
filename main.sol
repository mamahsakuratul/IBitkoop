// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBitkoopLedger {
    function slotCount() external view returns (uint256);
    function getSlot(uint256 index) external view returns (
        uint256 blockNum,
        bytes32 vid,
        uint256 valueWei,
        address user
    );
}

interface IBitkoopToken {
    function mint(address to, uint256 amount) external;
}

/// @title BitkoopGame — Earn BKOOP by daily claim, redeeming on Bitkoop, and coupon hunt
/// @notice Integrates with Bitkoop ledger: claim tokens for redemptions, daily login, and code hunts.
contract BitkoopGame {
    uint256 public constant BLOCKS_PER_DAY = 7200;
    uint256 public constant DAILY_REWARD = 50 * 1e18;
    uint256 public constant REDEEM_REWARD = 25 * 1e18;
    uint256 public constant COUPON_HUNT_REWARD = 100 * 1e18;
    uint256 public constant STREAK_BONUS_3 = 30 * 1e18;
    uint256 public constant STREAK_BONUS_7 = 80 * 1e18;
    uint256 public constant STREAK_BONUS_30 = 500 * 1e18;
    uint256 public constant MAX_SLOTS_PER_CLAIM = 30;

    IBitkoopLedger public immutable ledger;
    IBitkoopToken public immutable token;
    address public immutable gameOwner;

    uint256 public dailyReward;
    uint256 public redeemReward;
    uint256 public couponHuntReward;
    bool public paused;

    mapping(address => uint256) public lastDailyBlock;
    mapping(address => uint256) public lastClaimedSlotIndex;
    mapping(address => uint256) public streakDays;
    mapping(address => uint256) public lastStreakDayBlock;
    bytes32 public couponHuntHash;
    uint256 public couponHuntEndBlock;
    mapping(address => bool) public hasClaimedThisCouponHunt;

    error Game_Forbidden();
    error Game_ZeroAddress();
    error Game_Paused();
    error Game_TooSoon();
    error Game_NoNewRedemptions();
    error Game_CodeExpired();
    error Game_WrongCode();
    error Game_AlreadyClaimed();
    error Game_NoHashSet();

    event DailyClaimed(address indexed user, uint256 amount, uint256 streakDays);
    event RedemptionRewardsClaimed(address indexed user, uint256 slotsCredited, uint256 amount);
    event CouponHuntWon(address indexed user, uint256 amount);
    event CouponHuntSet(bytes32 hash, uint256 endBlock);
    event RewardsUpdated(uint256 daily, uint256 redeem, uint256 couponHunt);
    event PauseSet(bool paused);

    constructor(address _ledger, address _token, address _gameOwner) {
        if (_ledger == address(0) || _token == address(0) || _gameOwner == address(0)) revert Game_ZeroAddress();
        ledger = IBitkoopLedger(_ledger);
        token = IBitkoopToken(_token);
        gameOwner = _gameOwner;
        dailyReward = DAILY_REWARD;
        redeemReward = REDEEM_REWARD;
        couponHuntReward = COUPON_HUNT_REWARD;
    }

    modifier onlyOwner() {
        if (msg.sender != gameOwner) revert Game_Forbidden();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert Game_Paused();
        _;
    }

    /// @notice Claim daily reward (once per BLOCKS_PER_DAY). Streak bonus if consecutive days.
    function claimDaily() external whenNotPaused {
        uint256 nowBlock = block.number;
        uint256 last = lastDailyBlock[msg.sender];
        if (last != 0 && nowBlock < last + BLOCKS_PER_DAY) revert Game_TooSoon();

        uint256 reward = dailyReward;
        uint256 streak = streakDays[msg.sender];
        uint256 dayBlock = (last == 0) ? nowBlock : last;
        if (last != 0) {
            if (nowBlock >= lastStreakDayBlock[msg.sender] + BLOCKS_PER_DAY) {
                uint256 daysSince = (nowBlock - lastStreakDayBlock[msg.sender]) / BLOCKS_PER_DAY;
