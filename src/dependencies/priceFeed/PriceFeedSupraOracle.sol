// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {ISupraSValueFeed} from "../../interfaces/dependencies/priceFeed/ISupraSValueFeed.sol";
import {ISupraOraclePull} from "../../interfaces/dependencies/priceFeed/ISupraOraclePull.sol";
/**
 * @title PriceFeed Contract to integrate with Supra Oracle
 *        Convert data from interface of Supra Oracle to Satoshi's IPriceFeed
 */

contract PriceFeedSupraOracle is IPriceFeed, SatoshiOwnable {
    ISupraSValueFeed public immutable _source;
    ISupraOraclePull public immutable _pullSource;
    uint8 internal immutable _decimals;
    string internal _key;
    uint256 public maxTimeThreshold;
    uint256 internal pairIndex;

    constructor(
        ISatoshiCore _satoshiCore,
        ISupraSValueFeed source_,
        ISupraOraclePull pullSource_,
        uint8 decimals_,
        uint256 _maxTimeThreshold,
        uint256 _pairIndex
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        _pullSource = pullSource_;
        _decimals = decimals_;
        maxTimeThreshold = _maxTimeThreshold;
        pairIndex = _pairIndex;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        ISupraSValueFeed.priceFeed memory pricefeed = _source.getSvalue(pairIndex);
        if (pricefeed.price == 0) revert InvalidPriceUInt256(pricefeed.price);
        if (block.timestamp - uint256(pricefeed.time) > maxTimeThreshold) {
            revert PriceTooOld();
        }

        return pricefeed.price;
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        ISupraSValueFeed.priceFeed memory pricefeed = _source.getSvalue(pairIndex);
        if (pricefeed.price == 0) revert InvalidPriceUInt256(pricefeed.price);

        return (pricefeed.price, pricefeed.time);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function source() external view returns (address) {
        return address(_pullSource);
    }
}
