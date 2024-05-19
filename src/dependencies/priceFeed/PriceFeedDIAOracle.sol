// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {IDIAOracleV2} from "../../interfaces/dependencies/priceFeed/IDIAOracleV2.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with DIA Oracle
 *        Convert data from interface of DIA Oracle to Satoshi's IPriceFeed
 */
contract PriceFeedDIAOracle is IPriceFeed, SatoshiOwnable {
    IDIAOracleV2 internal immutable _source;
    uint8 internal immutable _decimals;
    string internal _key;
    uint256 public maxTimeThreshold;

    constructor(
        IDIAOracleV2 source_,
        uint8 decimals_,
        string memory key_,
        ISatoshiCore _satoshiCore,
        uint256 _maxTimeThreshold
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        _source = source_;
        _decimals = decimals_;
        _key = key_;
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function fetchPrice() external returns (uint256) {
        (uint128 price, uint128 lastUpdated) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);
        if (block.timestamp - uint256(lastUpdated) > maxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function fetchPriceUnsafe() external returns (uint256, uint256) {
        (uint128 price, uint128 lastUpdated) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);
        return (uint256(price), uint256(lastUpdated));
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
