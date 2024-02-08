// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

contract PriceFeedChainlink is IPriceFeed {
    AggregatorV3Interface internal immutable _source;

    constructor(AggregatorV3Interface source_) {
        _source = source_;
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price,,,) = _source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        return uint256(price);
    }

    function decimals() external view returns (uint8) {
        return _source.decimals();
    }
}
