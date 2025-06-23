// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StrategyManager} from "src/StrategyManager.sol";
import {CCIPRouterAdapter} from "src/CCIPRouterAdapter.sol";
import {IStrategy} from "src/IStrategy.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {ERC20Mock} from "test/mocks/ERC20Mock.sol";
import {Vault} from "src/Vault.sol";
import {AaveStrategy} from "src/strategies/AaveStrategy.sol";
import {MorphoStrategy} from "src/strategies/MorphoStrategy.sol";
import {PortfolioLib} from "src/PortfolioLib.sol";

// Mock for CCIP Adapter to capture sendMessage calls
contract MockCCIPAdapter is CCIPRouterAdapter {
    bytes public lastMessageData;
    uint64 public lastDestinationChainSelector;
    uint256 public fee;
    bytes32 public messageIdToReturn = bytes32(uint256(1));

    constructor() CCIPRouterAdapter(address(0), address(0)) {}

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
        return messageIdToReturn;
    }
}

// Mock for a strategy to capture deposit calls
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


contract StrategyManagerTest is Test {
    StrategyManager public manager;
    MockCCIPAdapter public mockAdapter;
    ERC20Mock public asset;
    
    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        vm.prank(owner);
        asset = new ERC20Mock("Asset", "ASSET", 18);
        
        // Cannot directly instantiate abstract contract, so we deploy a mock and cast it
        // A better approach would be to make the adapter an internal dependency, but this works for testing
        mockAdapter = new MockCCIPAdapter();
        
        // In the real contract, the adapter is created internally. For this test, we deploy the manager
        // and then overwrite the immutable adapter address in storage.
        manager = new StrategyManager(owner, address(asset), 8453, mockAdapter);
    }

    function test_addChainStrategy() public {
        uint64 chainSelector = 1;
        address strategyAddr = address(0xABC);
        
        vm.prank(owner);
        manager.addChainStrategy(chainSelector, strategyAddr);
        
        IStrategy[] memory strategies = manager.getChainStrategies(chainSelector);
        assertEq(strategies.length, 1, "Strategy count");
        assertEq(address(strategies[0]), strategyAddr, "Strategy address");
        assertTrue(manager.isStrategyRegistered(chainSelector, strategyAddr), "isStrategyRegistered");
    }

    function test_fail_addChainStrategy_notOwner() public {
        vm.prank(user); // Non-owner
        vm.expectRevert();
        manager.addChainStrategy(1, address(0x123));
    }
    
    function test_ccipReceive_deposits_to_strategy() public {
        uint64 sourceChainSelector = 123;
        uint256 depositAmount = 50e18;

        // 1. Register a mock strategy
        MockStrategy mockStrategy = new MockStrategy();
        vm.prank(owner);
        manager.addChainStrategy(sourceChainSelector, address(mockStrategy));
        
        // 2. Prepare the CCIP message
        uint16 strategyIndex = 0;
        bytes memory messageData = abi.encode(strategyIndex, depositAmount);
        
        Client.Any2EVMMessage memory message = Client.Any2EVMMessage({
            messageId: bytes32(uint256(1)),
            sourceChainSelector: sourceChainSelector,
            sender: abi.encode(address(this)),
            data: messageData,
            destTokenAmounts: new Client.EVMTokenAmount[](0)
        });

        // 3. Fund the manager with the asset (as if it came from the bridge)
        asset.mint(address(manager), depositAmount);

        // 4. Call ccipReceive (simulating call from CCIP Router)
        // vm.prank(address(ccipAdapter.getRouter())); // This would be ideal but router is address(0) in mock
        manager.ccipReceive(message);

        // 5. Check that the mock strategy was called correctly
        assertEq(mockStrategy.lastDepositAmount(), depositAmount, "Deposit amount mismatch");
    }

    function test_onDeposit_sends_CrossChain_for_other_chains_only() public {
        // managerのthisChainSelectorをBase(8453)として再デプロイ
        manager = new StrategyManager(owner, address(asset), 8453, mockAdapter);

        uint256 depositAmount = 100e18;
        PortfolioLib.Allocation[] memory allocations = new PortfolioLib.Allocation[](3);
        allocations[0] = PortfolioLib.Allocation({destinationChainSelector: 8453, strategyIndex: 0, percentage: 2000}); // Base 20%
        allocations[1] = PortfolioLib.Allocation({destinationChainSelector: 1, strategyIndex: 0, percentage: 5000});    // Ethereum 50%
        allocations[2] = PortfolioLib.Allocation({destinationChainSelector: 42161, strategyIndex: 0, percentage: 3000}); // Arbitrum 30%

        // onDeposit実行（msg.value=0でOK）
        manager.onDeposit(depositAmount, allocations);

        // MockCCIPAdapterのlastMessageDataが正しくセットされているか（最後の呼び出しがArbitrum分）
        (address receiver, bytes memory data, address token, uint256 amount) = abi.decode(mockAdapter.lastMessageData(), (address, bytes, address, uint256));
        (uint16 strategyIndex, uint256 allocationAmount) = abi.decode(data, (uint16, uint256));
        assertEq(mockAdapter.lastDestinationChainSelector(), 42161, "last destination chain is Arbitrum");
        assertEq(allocationAmount, depositAmount * 3000 / 10000, "Arbitrum allocation amount");
    }
}
