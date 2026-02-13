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
