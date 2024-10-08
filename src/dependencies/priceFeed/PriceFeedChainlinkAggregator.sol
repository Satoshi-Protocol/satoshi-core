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
    AggregatorV3Interface[] internal _sources;
    uint256[] public maxTimeThresholds;
    uint256[] public ratio;

    constructor(
        AggregatorV3Interface[] memory sources_,
        ISatoshiCore _satoshiCore,
        uint256[] memory _maxTimeThreshold,
        uint256[] memory _ratio
    ) {
        require(
            sources_.length == _ratio.length && _maxTimeThreshold.length == sources_.length,
            "PriceFeedChainlinkAggregator: Invalid length"
        );
        __SatoshiOwnable_init(_satoshiCore);
        uint256 length = sources_.length;
        for (uint256 i; i < length; ++i) {
            _sources.push(sources_[i]);
            maxTimeThresholds.push(_maxTimeThreshold[i]);
            ratio.push(_ratio[i]);
        }
    }

    function fetchPrice() external view returns (uint256 finalPrice) {
        uint256 ratioSum;
        for (uint256 i; i < _sources.length; ++i) {
            (, int256 price,, uint256 updatedAt,) = _sources[i].latestRoundData();

            if (price <= 0) revert InvalidPriceInt256(price);
            if (block.timestamp - updatedAt > maxTimeThresholds[i]) {
                revert PriceTooOld();
            }

            finalPrice += uint256(price) * ratio[i];
            ratioSum += ratio[i];
        }

        finalPrice /= ratioSum;

        return finalPrice;
    }

    function fetchPriceUnsafe() external view returns (uint256 finalPrice, uint256 updatedAt) {
        uint256 ratioSum;
        uint256 length = _sources.length;
        for (uint256 i; i < length; ++i) {
            (, int256 price,, uint256 updatedAt0,) = _sources[i].latestRoundData();

            if (price <= 0) revert InvalidPriceInt256(price);

            finalPrice += uint256(price) * ratio[i];
            ratioSum += ratio[i];

            if (updatedAt0 > updatedAt) {
                updatedAt = updatedAt0;
            }
        }

        finalPrice /= ratioSum;
    }

    function decimals() external view returns (uint8) {
        return _sources[0].decimals();
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        if (_maxTimeThreshold <= 120) {
            revert InvalidMaxTimeThreshold();
        }

        maxTimeThresholds[0] = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function updateMaxTimeThresholds(uint256[] memory _maxTimeThreshold) external onlyOwner {
        require(_maxTimeThreshold.length == _sources.length, "PriceFeedChainlinkAggregator: Invalid length");
        uint256 length = _maxTimeThreshold.length;
        delete maxTimeThresholds;
        for (uint256 i; i < length; ++i) {
            if (_maxTimeThreshold[i] <= 120) {
                revert InvalidMaxTimeThreshold();
            }
            maxTimeThresholds.push(_maxTimeThreshold[i]);
        }
        emit MaxTimeThresholdsUpdated(_maxTimeThreshold);
    }

    function setRatio(uint256[] calldata ratio_) external onlyOwner {
        require(ratio_.length == _sources.length, "PriceFeedChainlinkAggregator: Invalid length");
        delete ratio;
        for (uint256 i; i < ratio_.length; ++i) {
            ratio.push(ratio_[i]);
        }
        emit RatioUpdated(ratio_);
    }

    // retain for backward compatibility
    function maxTimeThreshold() external view returns (uint256) {
        return maxTimeThresholds[0];
    }

    // retain for backward compatibility
    function source() external view returns (address) {
        return address(_sources[0]);
    }

    function sources(uint256 i) external view returns (address) {
        return address(_sources[i]);
    }
}
