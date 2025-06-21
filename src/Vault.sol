// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626, ERC20} from "solmate/tokens/ERC4626.sol";
import {IStrategyManager} from "./StrategyManager.sol";
import {PortfolioLib} from "./PortfolioLib.sol";

/**
 * @title MultiChainVault
 * @author Your Name
 * @notice ERC-4626 Vault that acts as a single entry point for users,
 *         delegating all logic to a StrategyManager.
 */
contract Vault is ERC4626 {
    IStrategyManager public immutable strategyManager;

    /**
     * @param _asset The address of the underlying asset token.
     * @param _strategyManager The address of the StrategyManager contract.
     * @param _name The name for the Vault token.
     * @param _symbol The symbol for the Vault token.
     */
    constructor(
        ERC20 _asset,
        IStrategyManager _strategyManager,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {
        strategyManager = _strategyManager;
    }

    /**
     * @notice Returns the total amount of underlying assets held by the vault
     *         across all chains and strategies.
     * @return total The total amount of assets.
     */
    function totalAssets() public view override returns (uint256) {
        return strategyManager.totalAssets();
    }

    /**
     * @dev Hook that is called after a deposit is processed.
     *      Notifies the StrategyManager of the incoming deposit.
     */
    function afterDeposit(uint256 assets, uint256 shares) internal override {
        // For the purpose of this implementation, we will use a placeholder allocation.
        // In a real dApp, this data would come from the user.
        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](
            0
        );
        strategyManager.onDeposit{value: msg.value}(assets, allocations);
    }

    /**
     * @dev Hook that is called before a withdrawal is processed.
     *      Notifies the StrategyManager of the impending withdrawal.
     */
    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // The StrategyManager would need a corresponding `onWithdraw` function
        // to coordinate asset retrieval from other chains.
        // strategyManager.onWithdraw(assets);
    }
}
