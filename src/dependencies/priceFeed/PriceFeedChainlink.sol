// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 */
contract PriceFeedChainlink is IPriceFeed, SatoshiOwnable {
    AggregatorV3Interface internal immutable _source;
    uint256 public maxTimeThreshold;

    constructor(AggregatorV3Interface source_, ISatoshiCore _satoshiCore) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        maxTimeThreshold = 86400;
        emit MaxTimeThresholdUpdated(86400);
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = _source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        if (block.timestamp - updatedAt > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function decimals() external view returns (uint8) {
        return _source.decimals();
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        if (_maxTimeThreshold <= 120) {
            revert InvalidMaxTimeThreshold();
        }

        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function source() external view returns (address) {
        return address(_source);
    }
}
