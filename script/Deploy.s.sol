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
            router: 0x8f35Ea931ac7E2A5c1c7b5B5e3E2b1C6C8E40b01,
            link: 0xD886E2286Fd1073df82462ea1822119600Af80b6,
            chainSelector: 84532,
            name: "Base Sepolia"
        });
        // Arbitrum Sepolia
        configs["arbitrum"] = NetworkConfig({
            router: 0xbc09B44bE5bf8B1f6f8bb1Bb8B1Bb8b1BB8b944f,
            link: 0x6b0BE2a3e3E2b1c6c8E40b01B8b8B8b8B8b8B8B8,
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