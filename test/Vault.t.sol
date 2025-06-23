// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {IStrategyManager} from "src/StrategyManager.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {PortfolioLib} from "src/PortfolioLib.sol";
import {IStrategy} from "src/IStrategy.sol";

contract MockStrategyManager is IStrategyManager {
    uint256 public mockTotalAssets;
    bytes public lastOnDepositData;

    function onDeposit(
        uint256 amount,
        PortfolioLib.Allocation[] calldata allocations
    ) external payable {
        lastOnDepositData = abi.encode(amount, allocations);
    }

    function totalAssets() external view returns (uint256) {
        return mockTotalAssets;
    }

    function setMockTotalAssets(uint256 value) external {
        mockTotalAssets = value;
    }

    // Unused functions
    function addChainStrategy(uint64, address) external {}
    function getChainStrategies(uint64)
        external
        view
        returns (IStrategy[] memory)
    {
        IStrategy[] memory a;
        return a;
    }

    function isStrategyRegistered(uint64, address) external view returns (bool) {
        return false;
    }

    function ccipReceive(Client.Any2EVMMessage calldata) external {}
}

contract VaultTest is Test {
    Vault public vault;
    ERC20Mock public asset;
    MockStrategyManager public strategyManager;

    address public constant USER = address(0x2);
    uint256 public constant DEPOSIT_AMOUNT = 100e18;

    function setUp() public {
        asset = new ERC20Mock("Mock Token", "MOCK", 18);
        strategyManager = new MockStrategyManager();
        vault = new Vault(asset, strategyManager, "Vault Token", "VT");

        asset.mint(USER, DEPOSIT_AMOUNT * 2);
    }

    function test_deposit_and_mint_shares() public {
        strategyManager.setMockTotalAssets(0); // Initial state
        vm.startPrank(USER);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositOnly(DEPOSIT_AMOUNT, USER);
        vm.stopPrank();

        assertEq(vault.balanceOf(USER), DEPOSIT_AMOUNT, "Shares minted");
        assertEq(vault.pendingDeposit(USER), DEPOSIT_AMOUNT, "Pending deposit updated");

        // After deposit, the strategy manager should reflect the new total assets.
        // We simulate this by updating our mock.
        strategyManager.setMockTotalAssets(DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT, "Total assets updated");
    }

    function test_distributePendingDeposit_calls_onDeposit_and_clears_pending() public {
        strategyManager.setMockTotalAssets(0);
        vm.startPrank(USER);
        asset.approve(address(vault), DEPOSIT_AMOUNT);
        vault.depositOnly(DEPOSIT_AMOUNT, USER);
        assertEq(vault.pendingDeposit(USER), DEPOSIT_AMOUNT, "Pending deposit after depositOnly");

        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](3);
        allocations[0] = PortfolioLib.Allocation({destinationChainSelector: 8453, strategyIndex: 0, percentage: 2000}); // Base 20%
        allocations[1] = PortfolioLib.Allocation({destinationChainSelector: 1, strategyIndex: 0, percentage: 5000});    // Ethereum 50%
        allocations[2] = PortfolioLib.Allocation({destinationChainSelector: 42161, strategyIndex: 0, percentage: 3000}); // Arbitrum 30%

        vault.distributePendingDeposit(allocations);
        assertEq(vault.pendingDeposit(USER), 0, "Pending deposit cleared");

        // onDepositが正しい値で呼ばれたか検証
        (uint256 receivedAmount, PortfolioLib.Allocation[] memory receivedAllocations) = abi.decode(strategyManager.lastOnDepositData(), (uint256, PortfolioLib.Allocation[]));
        assertEq(receivedAmount, DEPOSIT_AMOUNT, "onDeposit amount");
        assertEq(receivedAllocations.length, 3, "allocations length");
        assertEq(receivedAllocations[0].destinationChainSelector, 8453, "base selector");
        assertEq(receivedAllocations[1].destinationChainSelector, 1, "eth selector");
        assertEq(receivedAllocations[2].destinationChainSelector, 42161, "arb selector");
        assertEq(receivedAllocations[0].percentage, 2000, "base %");
        assertEq(receivedAllocations[1].percentage, 5000, "eth %");
        assertEq(receivedAllocations[2].percentage, 3000, "arb %");
        vm.stopPrank();
    }
}
