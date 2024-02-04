// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPriceFeed {
    function fetchPrice() external returns (uint256);

    function decimals() external view returns (uint8);
}
