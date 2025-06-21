// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IStrategy} from "./IStrategy.sol";
import {Owned} from "solmate/auth/Owned.sol";
import {PortfolioLib} from "./PortfolioLib.sol";
import {CCIPRouterAdapter} from "./CCIPRouterAdapter.sol";
import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

/**
 * @title IStrategyManager
 * @notice Interface for the StrategyManager, which handles cross-chain logic.
 */
interface IStrategyManager {
    function onDeposit(
        uint256 amount,
        PortfolioLib.Allocation[] calldata allocations
    ) external payable;

    function totalAssets() external view returns (uint256);

    function addChainStrategy(uint64 chainSelector, address strategy) external;

    function getChainStrategies(
        uint64 chainSelector
    ) external view returns (IStrategy[] memory);

    function isStrategyRegistered(
        uint64 chainSelector,
        address strategy
    ) external view returns (bool);

    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external;
}

/**
 * @title StrategyManager
 * @author Your Name
 * @notice Core logic for managing strategies across multiple chains via CCIP.
 */
contract StrategyManager is IStrategyManager, Owned {
    CCIPRouterAdapter public immutable ccipAdapter;
    address public immutable asset;

    // Mapping from chain selector to a list of strategy addresses
    mapping(uint64 => IStrategy[]) internal chainStrategies;
    // Mapping to quickly check if a strategy is registered for a given chain
    mapping(uint64 => mapping(address => bool)) internal isStrategyRegisteredMapping;

    constructor(
        address _owner,
        address router,
        address link,
        address _asset
    ) Owned(_owner) {
        ccipAdapter = new CCIPRouterAdapter(router, link);
        asset = _asset;
    }

    function onDeposit(
        uint256 amount,
        PortfolioLib.Allocation[] calldata allocations
    ) external payable override {
        PortfolioLib.validateAllocations(allocations);
        // For each allocation, send a CCIP message to the destination chain's strategy
        for (uint i = 0; i < allocations.length; i++) {
            PortfolioLib.Allocation memory allocation = allocations[i];
            uint256 allocationAmount = (amount * allocation.percentage) /
                PortfolioLib.PERCENTAGE_BASIS;

            // Prepare the data for the remote strategy's deposit function
            bytes memory messageData = abi.encode(
                allocation.strategyIndex,
                allocationAmount
            );

            // Send the message via CCIP
            ccipAdapter.sendMessage{value: msg.value}(
                allocation.destinationChainSelector,
                address(this), // The receiver is this contract on the destination chain
                messageData,
                asset,
                allocationAmount,
                address(0) // Fee token address, use native gas
            );
        }
    }

    function totalAssets() external view override returns (uint256) {
        // This would require aggregating totalAssets from all strategies across all chains,
        // which is complex and likely needs off-chain support or a more advanced cross-chain design.
        // For now, returning 0 as a placeholder.
        return 0;
    }

    function ccipReceive(
        Client.Any2EVMMessage calldata message
    ) external override {
        // require(msg.sender == address(ccipAdapter.getRouter()), "Only router");
        (uint16 strategyIndex, uint256 depositAmount) = abi.decode(
            message.data,
            (uint16, uint256)
        );

        IStrategy[] storage strategies = chainStrategies[
            message.sourceChainSelector
        ];
        require(strategyIndex < strategies.length, "Invalid strategy index");

        IStrategy strategy = strategies[strategyIndex];
        LinkTokenInterface(asset).approve(address(strategy), depositAmount);
        strategy.deposit(depositAmount);
    }
    
    function addChainStrategy(uint64 chainSelector, address strategy) external override onlyOwner {
        require(strategy != address(0), "Zero address");
        require(!isStrategyRegisteredMapping[chainSelector][strategy], "Already registered");
        chainStrategies[chainSelector].push(IStrategy(strategy));
        isStrategyRegisteredMapping[chainSelector][strategy] = true;
    }

    function getChainStrategies(
        uint64 chainSelector
    ) external view override returns (IStrategy[] memory) {
        return chainStrategies[chainSelector];
    }

    function isStrategyRegistered(
        uint64 chainSelector,
        address strategy
    ) external view override returns (bool) {
        return isStrategyRegisteredMapping[chainSelector][strategy];
    }
}
