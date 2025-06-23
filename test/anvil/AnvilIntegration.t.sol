// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {StrategyManager} from "src/StrategyManager.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {MockCCIPAdapter} from "test/mocks/MockCCIPAdapter.sol";

contract AnvilIntegrationTest is Test {
    Vault public vault;
    StrategyManager public manager;
    ERC20Mock public usdc;
    MockCCIPAdapter public adapter;
    address public user = address(0x2);

    function setUp() public {
        // anvilのデフォルトアカウント(0)でブロードキャスト
        vm.startBroadcast(vm.envUint("PRIVATE_KEY")); // PRIVATE_KEYは.envで指定
        usdc = new ERC20Mock("Test USDC", "USDC", 6);
        adapter = new MockCCIPAdapter();
        manager = new StrategyManager(msg.sender, address(usdc), 1, adapter);
        vault = new Vault(usdc, manager, "Vault", "VT");
        vm.stopBroadcast();
    }

    function test_depositAndWithdraw() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        usdc.mint(user, 100e6);
        vm.stopBroadcast();

        vm.startPrank(user);
        usdc.approve(address(vault), 100e6);
        vault.depositOnly(100e6, user);
        assertEq(usdc.balanceOf(address(vault)), 100e6, "Vault should have 100 USDC");
        vm.stopPrank();
    }
} 