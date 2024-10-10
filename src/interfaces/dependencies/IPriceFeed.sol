// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiOwnable} from "./ISatoshiOwnable.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

struct SourceConfig {
    AggregatorV3Interface source;
    uint256 maxTimeThreshold;
    uint256 weight;
}

interface IPriceFeed is ISatoshiOwnable {
    // invalid price error for different types of price sources
    error InvalidPriceInt256(int256 price);
    error InvalidPriceUInt128(uint128 price);
    error InvalidPriceInt224(int224 price);
    error InvalidPriceUInt256(uint256 price);
    error PriceTooOld();
    error InvalidMaxTimeThreshold();
    error Deprecated();

    // Events
    event MaxTimeThresholdUpdated(uint256 newMaxTimeThreshold);
    event MaxTimeThresholdsUpdated(uint256[] newMaxTimeThreshold);
    event PriceIDUpdated(bytes32 newPriceID);
    event ConfigSet(SourceConfig[] sources);

    function fetchPrice() external returns (uint256);

    function fetchPriceUnsafe() external returns (uint256, uint256);

    function decimals() external view returns (uint8);

    function maxTimeThreshold() external view returns (uint256);

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external;

    function source() external view returns (address);
}
