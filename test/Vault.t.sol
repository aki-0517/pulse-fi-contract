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
        
        // In a real scenario, allocations would be provided. Here it's empty.
        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](0);
        vault.deposit(DEPOSIT_AMOUNT, USER); // Note: Simplified call for ERC4626, onDeposit is internal
        
        vm.stopPrank();

        assertEq(vault.balanceOf(USER), DEPOSIT_AMOUNT, "Shares minted");

        // After deposit, the strategy manager should reflect the new total assets.
        // We simulate this by updating our mock.
        strategyManager.setMockTotalAssets(DEPOSIT_AMOUNT);
        assertEq(vault.totalAssets(), DEPOSIT_AMOUNT, "Total assets updated");
        
        // Verify manager was called
        (uint256 receivedAmount, ) = abi.decode(strategyManager.lastOnDepositData(), (uint256, PortfolioLib.Allocation[]));
        assertEq(receivedAmount, DEPOSIT_AMOUNT, "Manager onDeposit amount");
    }
}
