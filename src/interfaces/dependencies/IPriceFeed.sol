// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPriceFeed {
    // invalid price error for different types of price sources
    error InvalidPriceInt256(int256 price);
    error InvalidPriceUInt128(uint128 price);
    error PriceTooOld();
    error InvalidTime();

    // Events
    event DIAParamsUpdated(uint128 diaMaxTimeThreshold);

    function fetchPrice() external returns (uint256);

    function decimals() external view returns (uint8);
}
