// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPriceFeed {
    error InvalidPrice(int256 price);

    function fetchPrice() external view returns (uint256);

    function decimals() external view returns (uint8);
}
