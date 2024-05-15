// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiOwnable} from "./ISatoshiOwnable.sol";

interface IPriceFeedPyth is ISatoshiOwnable {
    // invalid price error for different types of price sources
    error InvalidPriceInt256(int256 price);
    error InvalidPriceUInt128(uint128 price);
    error PriceTooOld();
    error InvalidMaxTimeThreshold();
    error RefundFailed();

    // Events
    event MaxTimeThresholdUpdated(uint256 newMaxTimeThreshold);
    event PriceIDUpdated(bytes32 newPriceID);

    function decimals() external view returns (uint8);

    function fetchPrice() external returns (uint256);

    function setPriceID(bytes32 priceID_) external;

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external;

    function updateFeeds(bytes[] calldata priceUpdateData) external payable;
}
