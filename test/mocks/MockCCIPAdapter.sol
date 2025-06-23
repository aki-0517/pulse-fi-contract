// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CCIPRouterAdapter} from "src/CCIPRouterAdapter.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";

contract MockCCIPAdapter is CCIPRouterAdapter {
    bytes public lastMessageData;
    uint64 public lastDestinationChainSelector;
    uint256 public fee;
    bytes32 public messageIdToReturn = bytes32(uint256(1));
    address public lastReceiver;
    address public lastSender;
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
        if (mockRemoteManagers[_destinationChainSelector] != address(0)) {
            (uint16 strategyIndex, uint256 allocationAmount) = abi.decode(_data, (uint16, uint256));
            bytes memory sender = abi.encode(msg.sender);
            Client.EVMTokenAmount[] memory destTokenAmounts = new Client.EVMTokenAmount[](0);
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