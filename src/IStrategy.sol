// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStrategy
 * @author Your Name
 * @notice Interface for all yield-generating strategies.
 */
interface IStrategy {
    /**
     * @notice Deposits assets into the strategy.
     * @param amount The amount of assets to deposit.
     */
    function deposit(uint256 amount) external;

    /**
     * @notice Withdraws assets from the strategy.
     * @param amount The amount of assets to withdraw.
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice Returns the total assets managed by the strategy.
     * @return The total assets.
     */
    function totalAssets() external view returns (uint256);
}
