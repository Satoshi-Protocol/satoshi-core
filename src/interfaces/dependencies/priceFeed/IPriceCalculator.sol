// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IPriceCalculator {
    struct ReferenceData {
        uint256 lastData;
        uint256 lastUpdated;
    }

    function priceOf(address asset) external view returns (uint256);

    function pricesOf(address[] memory assets) external view returns (uint256[] memory);

    function priceOfETH() external view returns (uint256);

    function priceOfBTC() external view returns (uint256);

    function getTimestampFromLatestUpdate(address asset) external view returns (uint256);

    function getLatestRoundParams() external view returns (uint256, uint128, uint256);
}
