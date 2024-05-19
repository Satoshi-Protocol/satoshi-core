// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {IProxy} from "@api3/contracts/api3-server-v1/proxies/interfaces/IProxy.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with API3 Oracle
 *        Convert data from interface of API3 Oracle to Satoshi's IPriceFeed
 */
contract PriceFeedAPI3Oracle is IPriceFeed, SatoshiOwnable {
    IProxy internal immutable _source;
    uint8 internal immutable _decimals;
    string internal _key;
    uint256 public maxTimeThreshold;

    constructor(IProxy source_, uint8 decimals_, ISatoshiCore _satoshiCore, uint256 _maxTimeThreshold) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        _decimals = decimals_;
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external view returns (uint256) {
        (int224 price, uint32 lastUpdated) = _source.read();
        if (price <= 0) revert InvalidPriceInt224(price);
        if (block.timestamp - uint256(lastUpdated) > maxTimeThreshold) {
            revert PriceTooOld();
        }

        return uint256(uint224(price));
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        (int224 price, uint32 lastUpdated) = _source.read();
        if (price <= 0) revert InvalidPriceInt224(price);
        return (uint256(uint224(price)), uint256(lastUpdated));
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function source() external view returns (address) {
        return address(_source);
    }
}
