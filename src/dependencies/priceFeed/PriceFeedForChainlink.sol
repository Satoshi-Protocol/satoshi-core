// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/AggregatorV3Interface.sol";

contract PriceFeedForChainlink is IPriceFeed {
    AggregatorV3Interface internal priceFeed;

    constructor(AggregatorV3Interface _priceFeed) {
        priceFeed = _priceFeed;
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        if (price <= 0) revert InvalidPrice(price);
        return uint256(price);
    }

    function decimals() external view returns (uint8) {
        return priceFeed.decimals();
    }
}
