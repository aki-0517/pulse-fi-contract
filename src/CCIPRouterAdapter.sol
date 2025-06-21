// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts/src/v0.8/ccip/libraries/Client.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/shared/interfaces/LinkTokenInterface.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

/**
 * @title CCIPRouterAdapter
 * @author Your Name
 * @notice Wraps Chainlink CCIP Router interactions to simplify sending cross-chain messages.
 */
contract CCIPRouterAdapter {
    using SafeTransferLib for ERC20;

    IRouterClient private immutable i_router;
    LinkTokenInterface private immutable i_linkToken;

    event MessageSent(bytes32 indexed messageId);

    /**
     * @param _router The address of the CCIP Router contract.
     * @param _linkToken The address of the LINK token contract for fee payment.
     */
    constructor(address _router, address _linkToken) {
        i_router = IRouterClient(_router);
        i_linkToken = LinkTokenInterface(_linkToken);
    }

    /**
     * @notice Sends a cross-chain message with tokens.
     * @param _destinationChainSelector The CCIP selector for the destination chain.
     * @param _receiver The address of the receiver on the destination chain.
     * @param _data The calldata to be sent to the receiver.
     * @param _token The address of the token to transfer.
     * @param _amount The amount of the token to transfer.
     * @param _feeToken The address of the token to pay fees with (address(0) for native).
     */
    function sendMessage(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        address _feeToken
    ) external payable virtual returns (bytes32 messageId) {
        Client.EVM2AnyMessage memory message = _buildMessage(
            _receiver, _data, _token, _amount, _feeToken
        );

        uint256 fees = i_router.getFee(_destinationChainSelector, message);

        if (_feeToken == address(i_linkToken)) {
            // Pay with LINK
            i_linkToken.approve(address(i_router), fees);
        } else {
            // Pay with native currency
            require(msg.value >= fees, "Insufficient native fee");
        }
        
        // Send the message
        messageId = i_router.ccipSend{value: _feeToken == address(0) ? fees : 0}(
            _destinationChainSelector, message
        );

        emit MessageSent(messageId);
    }

    /**
     * @dev Helper function to construct the CCIP message.
     */
    function _buildMessage(
        address _receiver,
        bytes memory _data,
        address _token,
        uint256 _amount,
        address _feeToken
    ) private pure returns (Client.EVM2AnyMessage memory) {
        Client.EVMTokenAmount[] memory tokenAmounts;
        if (_token != address(0) && _amount > 0) {
            tokenAmounts = new Client.EVMTokenAmount[](1);
            tokenAmounts[0] = Client.EVMTokenAmount({
                token: _token,
                amount: _amount
            });
        }

        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver),
            data: _data,
            tokenAmounts: tokenAmounts,
            extraArgs: "",
            feeToken: _feeToken
        });
    }

    function getRouter() external view returns(address) {
        return address(i_router);
    }
}
