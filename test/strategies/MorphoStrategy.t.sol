// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MorphoStrategy} from "src/strategies/MorphoStrategy.sol";

contract MorphoStrategyTest is Test {
    MorphoStrategy public strategy;

    function setUp() public {
        strategy = new MorphoStrategy();
    }

    function test_revert_on_deposit() public {
        vm.expectRevert("MorphoStrategy.deposit: not implemented");
        strategy.deposit(1e18);
    }

    function test_revert_on_withdraw() public {
        vm.expectRevert("MorphoStrategy.withdraw: not implemented");
        strategy.withdraw(1e18);
    }

    function test_totalAssets() public {
        assertEq(strategy.totalAssets(), 0);
    }
} 