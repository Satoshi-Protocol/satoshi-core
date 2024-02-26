// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiOwnable} from "./ISatoshiOwnable.sol";

interface IPriceFeed is ISatoshiOwnable {
    // invalid price error for different types of price sources
    error InvalidPriceInt256(int256 price);
    error InvalidPriceUInt128(uint128 price);
    error PriceTooOld();
    error InvalidMaxTimeThreshold();

    // Events
    event MaxTimeThresholdUpdated(uint256 newMaxTimeThreshold);

    function fetchPrice() external returns (uint256);

    function decimals() external view returns (uint8);

    function maxTimeThreshold() external view returns (uint256);

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external;
}
