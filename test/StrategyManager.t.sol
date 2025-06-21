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
        manager = new StrategyManager(owner, address(0), address(0), address(asset));
        bytes32 slot = bytes32(uint256(uint160(address(manager))) | (uint256(uint96(2)) << 160));
        vm.store(address(manager), slot, bytes32(uint256(uint160(address(mockAdapter)))));
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
}
