// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategy} from "../IStrategy.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

/**
 * @title AaveStrategy
 * @author Your Name
 * @notice A strategy for depositing assets into the Aave V3 protocol.
 */
contract AaveStrategy is IStrategy {
    using SafeTransferLib for ERC20;

    IPool public immutable pool;
    address public immutable asset;
    address public immutable aToken;

    /**
     * @param _pool The address of the Aave V3 Pool contract.
     * @param _asset The address of the underlying asset to be deposited.
     * @param _aToken The address of the corresponding aToken.
     */
    constructor(address _pool, address _asset, address _aToken) {
        pool = IPool(_pool);
        asset = _asset;
        aToken = _aToken;
    }

    /**
     * @notice Deposits a given amount of the asset into the Aave V3 Pool.
     * @param amount The amount of the asset to deposit.
     */
    function deposit(uint256 amount) external override {
        ERC20(asset).safeApprove(address(pool), amount);
        pool.supply(asset, amount, address(this), 0);
    }

    /**
     * @notice Withdraws a given amount of the asset from the Aave V3 Pool.
     * @param amount The amount of the asset to withdraw.
     */
    function withdraw(uint256 amount) external override {
        pool.withdraw(asset, amount, address(this));
    }

    /**
     * @notice Returns the total amount of assets managed by this strategy.
     * @return The total assets, which is the balance of aTokens held by this contract.
     */
    function totalAssets() external view override returns (uint256) {
        return ERC20(aToken).balanceOf(address(this));
    }
}
