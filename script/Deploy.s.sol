// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {CCIPRouterAdapter} from "../src/CCIPRouterAdapter.sol";
import {StrategyManager} from "../src/StrategyManager.sol";
import {Vault} from "../src/Vault.sol";

contract Deploy is Script {
    // ネットワークごとのパラメータ
    struct NetworkConfig {
        address router;
        address link;
        uint64 chainSelector;
        string name;
    }

    mapping(string => NetworkConfig) internal configs;

    function setConfigs() internal {
        // Ethereum Sepolia
        configs["sepolia"] = NetworkConfig({
            router: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16015286601757825753,
            name: "Ethereum Sepolia"
        });
        // Base Sepolia
        configs["base"] = NetworkConfig({
            router: 0x8F35eA931aC7e2A5C1c7B5b5e3e2b1C6c8E40B01,
            link: 0xD886E2286Fd1073df82462ea1822119600Af80b6,
            chainSelector: 84532,
            name: "Base Sepolia"
        });
        // Arbitrum Sepolia
        configs["arbitrum"] = NetworkConfig({
            router: 0xBc09B44bE5bF8b1f6f8bB1bB8B1bB8B1bB8B944F,
            link: 0x6B0bE2a3e3e2b1C6c8E40B01B8B8B8B8B8B8B8B8,
            chainSelector: 421614,
            name: "Arbitrum Sepolia"
        });
    }

    function run() external {
        setConfigs();
        string memory net = vm.envString("TARGET_NET"); // "sepolia", "base", "arbitrum"
        NetworkConfig memory cfg = configs[net];
        address owner = msg.sender;

        vm.startBroadcast();

        // 1. テスト用USDCデプロイ
        ERC20Mock usdc = new ERC20Mock("Test USDC", "USDC", 6);
        console2.log("USDC address:", address(usdc));

        // 2. CCIPRouterAdapterデプロイ
        CCIPRouterAdapter adapter = new CCIPRouterAdapter(cfg.router, cfg.link);
        console2.log("CCIPRouterAdapter address:", address(adapter));

        // 3. StrategyManagerデプロイ
        StrategyManager manager = new StrategyManager(owner, address(usdc), cfg.chainSelector, adapter);
        console2.log("StrategyManager address:", address(manager));

        // 4. Vaultデプロイ
        Vault vault = new Vault(usdc, manager, string.concat("Vault ", cfg.name), string.concat("VT", net));
        console2.log("Vault address:", address(vault));

        vm.stopBroadcast();
    }
} 