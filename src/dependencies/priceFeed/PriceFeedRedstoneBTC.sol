// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {IPriceCalculator} from "../../interfaces/dependencies/priceFeed/IPriceCalculator.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 */
contract PriceFeedRedstoneBTC is IPriceFeed, SatoshiOwnable {
    IPriceCalculator internal immutable _source;
    uint256 public maxTimeThreshold;
    uint8 internal immutable _decimals;

    constructor(IPriceCalculator source_, ISatoshiCore _satoshiCore, uint8 decimals_, uint256 _maxTimeThreshold) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        maxTimeThreshold = _maxTimeThreshold;
        _decimals = decimals_;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        uint256 price = _source.priceOfBTC();
        if (price <= 0) revert InvalidPriceUInt256(price);
        uint256 updatedAt = _source.getTimestampFromLatestUpdate() / 1e3;
        if (block.timestamp - updatedAt > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return price;
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        uint256 price = _source.priceOfBTC();
        if (price <= 0) revert InvalidPriceUInt256(price);
        uint256 updatedAt = _source.getTimestampFromLatestUpdate() / 1e3;
        return (price, updatedAt);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
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
