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

