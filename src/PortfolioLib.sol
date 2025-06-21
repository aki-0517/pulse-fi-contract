// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title PortfolioLib
 * @author Your Name
 * @notice Utility library for handling portfolio allocation data.
 */
library PortfolioLib {
    // 100% is represented as 10,000 basis points for precision.
    uint256 public constant PERCENTAGE_BASIS = 10_000;

    /**
     * @dev Represents the allocation for a specific strategy on a specific chain.
     * @param destinationChainSelector The CCIP chain selector for the destination chain.
     * @param strategyIndex The index of the strategy on the destination chain.
     * @param percentage The percentage of assets to allocate, in basis points.
     */
    struct Allocation {
        uint64 destinationChainSelector;
        uint16 strategyIndex;
        uint16 percentage;
    }

    /**
     * @dev Thrown when the total percentage of allocations does not sum to 100%.
     * @param total The actual total percentage calculated.
     */
    error InvalidTotalPercentage(uint256 total);

    /**
     * @notice Validates that the sum of percentages in an array of allocations equals 100%.
     * @param allocations The array of allocation structs to validate.
     */
    function validateAllocations(Allocation[] memory allocations) internal pure {
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < allocations.length; i++) {
            totalPercentage += allocations[i].percentage;
        }

        if (totalPercentage != PERCENTAGE_BASIS) {
            revert InvalidTotalPercentage(totalPercentage);
        }
    }
} 