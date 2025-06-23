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

    // ユーザーごとの未分配残高
    mapping(address => uint256) public pendingDeposit;

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
        // ユーザーからの配分指定がない場合は何もしない
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

    /**
     * @notice ユーザーがVaultに資産をdepositする（分配はしない）
     * @param assets デポジットする資産量
     * @param receiver シェアの受取人
     */
    function depositOnly(uint256 assets, address receiver) external returns (uint256 shares) {
        shares = deposit(assets, receiver);
        pendingDeposit[receiver] += assets;
    }

    /**
     * @notice ユーザーが分配割合を指定して、未分配残高を分配する
     * @param allocations チェーンごとの分配割合
     */
    function distributePendingDeposit(PortfolioLib.Allocation[] calldata allocations) external payable {
        uint256 amount = pendingDeposit[msg.sender];
        require(amount > 0, "No pending deposit");
        pendingDeposit[msg.sender] = 0;
        strategyManager.onDeposit{value: msg.value}(amount, allocations);
    }

    /**
     * @notice ユーザーが割合配分を指定してdepositできる関数
     * @param assets デポジットする資産量
     * @param receiver シェアの受取人
     * @param allocations チェーンごとの分配割合
     */
    function depositWithAllocations(
        uint256 assets,
        address receiver,
        PortfolioLib.Allocation[] calldata allocations
    ) external payable returns (uint256 shares) {
        revert("Use depositOnly and distributePendingDeposit");
    }
}
