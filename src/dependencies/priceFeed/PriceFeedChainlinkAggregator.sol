// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 *        Aggregate multiple Chainlink price feeds
 */
contract PriceFeedChainlinkAggregator is IPriceFeed, SatoshiOwnable {
    AggregatorV3Interface internal immutable _source;
    AggregatorV3Interface internal immutable _source1;
    uint256 public maxTimeThreshold;
    uint256 public ratio1;
    uint256 public ratio2;

    constructor(
        AggregatorV3Interface source_,
        AggregatorV3Interface source1_,
        ISatoshiCore _satoshiCore,
        uint256 _maxTimeThreshold,
        uint256 _ratio1,
        uint256 _ratio2
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        _source1 = source1_;
        maxTimeThreshold = _maxTimeThreshold;
        ratio1 = _ratio1;
        ratio2 = _ratio2;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        (, int256 price0,, uint256 updatedAt0,) = _source.latestRoundData();
        (, int256 price1,, uint256 updatedAt1,) = _source1.latestRoundData();
        if (price0 <= 0) revert InvalidPriceInt256(price0);
        if (price1 <= 0) revert InvalidPriceInt256(price1);
        if (block.timestamp - updatedAt0 > maxTimeThreshold || block.timestamp - updatedAt1 > maxTimeThreshold) {
            revert PriceTooOld();
        }

        uint256 price = (uint256(price0) * ratio1 + uint256(price1) * ratio2) / (ratio1 + ratio2);

        return uint256(price);
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        (, int256 price0,, uint256 updatedAt0,) = _source.latestRoundData();
        (, int256 price1,,,) = _source1.latestRoundData();
        if (price0 <= 0) revert InvalidPriceInt256(price0);
        if (price1 <= 0) revert InvalidPriceInt256(price1);

        uint256 price = (uint256(price0) * ratio1 + uint256(price1) * ratio2) / (ratio1 + ratio2);

        return (uint256(price), updatedAt0);
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

    function setRatio(uint256 _ratio1, uint256 _ratio2) external onlyOwner {
        ratio1 = _ratio1;
        ratio2 = _ratio2;
        emit RatioUpdated(_ratio1, _ratio2);
    }

    function source() external view returns (address) {
        return address(_source);
    }

    function source1() external view returns (address) {
        return address(_source1);
    }
}
