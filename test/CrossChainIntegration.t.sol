// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Vault} from "src/Vault.sol";
import {StrategyManager} from "src/StrategyManager.sol";
import {CCIPRouterAdapter} from "src/CCIPRouterAdapter.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {PortfolioLib} from "src/PortfolioLib.sol";
import {IStrategy} from "src/IStrategy.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

// --- MockCCIPAdapter/MockStrategyはStrategyManager.t.solからコピー ---
contract MockCCIPAdapter is CCIPRouterAdapter {
    bytes public lastMessageData;
    uint64 public lastDestinationChainSelector;
    uint256 public fee;
    bytes32 public messageIdToReturn = bytes32(uint256(1));
    address public lastReceiver;
    address public lastSender;
    // クロスチェーン送信先のManagerを模擬的に呼び出す
    mapping(uint64 => address) public mockRemoteManagers;

    constructor() CCIPRouterAdapter(address(0), address(0)) {}

    function setMockRemoteManager(uint64 chainSelector, address manager) external {
        mockRemoteManagers[chainSelector] = manager;
    }

    function sendMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        address
    ) external payable override returns (bytes32) {
        lastDestinationChainSelector = _destinationChainSelector;
        lastMessageData = abi.encode(_receiver, _data, _token, _amount);
        lastReceiver = _receiver;
        lastSender = msg.sender;
        // 送信先のManagerのccipReceiveを直接呼ぶ（本来はCCIP経由）
        if (mockRemoteManagers[_destinationChainSelector] != address(0)) {
            (uint16 strategyIndex, uint256 allocationAmount) = abi.decode(_data, (uint16, uint256));
            // Client.Any2EVMMessageのモック
            bytes memory sender = abi.encode(msg.sender);
            // EVMTokenAmount[] を空配列で作成
            Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](0);
            // 構造体を組み立ててエンコード
            Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
                messageId: bytes32(uint256(1)),
                sourceChainSelector: _destinationChainSelector,
                sender: sender,
                data: _data,
                destTokenAmounts: destTokenAmounts
            });
            (bool ok,) = mockRemoteManagers[_destinationChainSelector].call(
                abi.encodeWithSignature(
                    "ccipReceive((bytes32,uint64,bytes,bytes,(address,uint256)[]))",
                    message
                )
            );
            require(ok, "remote ccipReceive failed");
        }
        return messageIdToReturn;
    }
}

contract MockStrategy is IStrategy {
    uint256 public lastDepositAmount;
    address public lastCaller;
    function deposit(uint256 amount) external {
        lastCaller = msg.sender;
        lastDepositAmount = amount;
    }
    function withdraw(uint256) external {}
    function totalAssets() external view returns (uint256) { return 0; }
}

contract CrossChainIntegrationTest is Test {
    // チェーンセレクタ
    uint64 constant SEPOLIA = 16015286601757825753;
    uint64 constant BASE = 8453;
    uint64 constant ARBITRUM = 42161;

    // 各チェーンのコントラクト
    Vault public vaultSepolia;
    Vault public vaultBase;
    Vault public vaultArbitrum;
    StrategyManager public managerSepolia;
    StrategyManager public managerBase;
    StrategyManager public managerArbitrum;
    MockCCIPAdapter public adapterSepolia;
    MockCCIPAdapter public adapterBase;
    MockCCIPAdapter public adapterArbitrum;
    ERC20Mock public usdc;
    MockStrategy public strategySepolia;
    MockStrategy public strategyBase;
    MockStrategy public strategyArbitrum;
    address public user = address(0x2);

    function setUp() public {
        // 1つのUSDCを全チェーンで共有（テスト用）
        usdc = new ERC20Mock("Test USDC", "USDC", 6);
        // 各チェーンのAdapter
        adapterSepolia = new MockCCIPAdapter();
        adapterBase = new MockCCIPAdapter();
        adapterArbitrum = new MockCCIPAdapter();
        // 各チェーンのStrategyManager
        managerSepolia = new StrategyManager(address(this), address(usdc), SEPOLIA, adapterSepolia);
        managerBase = new StrategyManager(address(this), address(usdc), BASE, adapterBase);
        managerArbitrum = new StrategyManager(address(this), address(usdc), ARBITRUM, adapterArbitrum);
        // Adapterに他チェーンのManagerを登録
        adapterSepolia.setMockRemoteManager(BASE, address(managerBase));
        adapterSepolia.setMockRemoteManager(ARBITRUM, address(managerArbitrum));
        adapterBase.setMockRemoteManager(SEPOLIA, address(managerSepolia));
        adapterBase.setMockRemoteManager(ARBITRUM, address(managerArbitrum));
        adapterArbitrum.setMockRemoteManager(SEPOLIA, address(managerSepolia));
        adapterArbitrum.setMockRemoteManager(BASE, address(managerBase));
        // 各チェーンのVault
        vaultSepolia = new Vault(usdc, managerSepolia, "Vault Sepolia", "VTSEP");
        vaultBase = new Vault(usdc, managerBase, "Vault Base", "VTBASE");
        vaultArbitrum = new Vault(usdc, managerArbitrum, "Vault Arbitrum", "VTARB");
        // 各チェーンのStrategy
        strategySepolia = new MockStrategy();
        strategyBase = new MockStrategy();
        strategyArbitrum = new MockStrategy();
        // 各チェーンのStrategyManagerにStrategyを登録
        managerSepolia.addChainStrategy(SEPOLIA, address(strategySepolia));
        managerBase.addChainStrategy(BASE, address(strategyBase));
        managerArbitrum.addChainStrategy(ARBITRUM, address(strategyArbitrum));
    }

    function test_baseDeposit_crossChainDistribution() public {
        // ユーザーに100USDCをmint
        usdc.mint(user, 100e6);
        // ユーザーがBase Vaultにapprove
        vm.startPrank(user);
        usdc.approve(address(vaultBase), 100e6);
        // depositOnly
        vaultBase.depositOnly(100e6, user);
        // 配分: base:sepolia:arbitrum = 2:5:3 (basis point)
        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](3);
        allocations[0] = PortfolioLib.Allocation({destinationChainSelector: BASE, strategyIndex: 0, percentage: 2000});
        allocations[1] = PortfolioLib.Allocation({destinationChainSelector: SEPOLIA, strategyIndex: 0, percentage: 5000});
        allocations[2] = PortfolioLib.Allocation({destinationChainSelector: ARBITRUM, strategyIndex: 0, percentage: 3000});
        // distributePendingDeposit
        vaultBase.distributePendingDeposit(allocations);
        vm.stopPrank();
        // 各チェーンのStrategyに正しい額がdepositされたか
        assertEq(strategyBase.lastDepositAmount(), 0, "Base allocation should be 0 (already in Vault)");
        assertEq(strategySepolia.lastDepositAmount(), 50e6, "Sepolia allocation should be 50 USDC");
        assertEq(strategyArbitrum.lastDepositAmount(), 30e6, "Arbitrum allocation should be 30 USDC");
    }

    function test_arbitrumDeposit_crossChainDistribution() public {
        usdc.mint(user, 100e6);
        vm.startPrank(user);
        usdc.approve(address(vaultArbitrum), 100e6);
        vaultArbitrum.depositOnly(100e6, user);
        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](3);
        allocations[0] = PortfolioLib.Allocation({destinationChainSelector: BASE, strategyIndex: 0, percentage: 2000});
        allocations[1] = PortfolioLib.Allocation({destinationChainSelector: SEPOLIA, strategyIndex: 0, percentage: 5000});
        allocations[2] = PortfolioLib.Allocation({destinationChainSelector: ARBITRUM, strategyIndex: 0, percentage: 3000});
        vaultArbitrum.distributePendingDeposit(allocations);
        vm.stopPrank();
        assertEq(strategyBase.lastDepositAmount(), 20e6, "Base allocation should be 20 USDC");
        assertEq(strategySepolia.lastDepositAmount(), 50e6, "Sepolia allocation should be 50 USDC");
        assertEq(strategyArbitrum.lastDepositAmount(), 0, "Arbitrum allocation should be 0 (already in Vault)");
    }
} 