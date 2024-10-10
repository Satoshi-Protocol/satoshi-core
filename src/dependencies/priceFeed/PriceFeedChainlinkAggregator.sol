// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed, SourceConfig} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 *        Aggregate multiple Chainlink price feeds
 */
contract PriceFeedChainlinkAggregator is IPriceFeed, SatoshiOwnable {
    uint8 public constant TARGET_DIGITS = 18;
    SourceConfig[] public sources;

    constructor(ISatoshiCore _satoshiCore, SourceConfig[] memory _sources) {
        __SatoshiOwnable_init(_satoshiCore);
        uint256 length = _sources.length;
        for (uint256 i; i < length; ++i) {
            sources.push(_sources[i]);
        }
        emit ConfigSet(_sources);
    }

    // --- External Functions ---
    function fetchPrice() external view returns (uint256 finalPrice) {
        uint256 weightSum;
        for (uint256 i; i < sources.length; ++i) {
            (, int256 price,, uint256 updatedAt,) = sources[i].source.latestRoundData();

            if (price <= 0) revert InvalidPriceInt256(price);
            if (block.timestamp - updatedAt > sources[i].maxTimeThreshold) {
                revert PriceTooOld();
            }

            uint256 scaledPrice = getScaledPrice(uint256(price), sources[i].source.decimals());

            finalPrice += scaledPrice * sources[i].weight;
            weightSum += sources[i].weight;
        }

        finalPrice /= weightSum;

        return finalPrice;
    }

    function fetchPriceUnsafe() external view returns (uint256 finalPrice, uint256 updatedAt) {
        uint256 weightSum;
        uint256 length = sources.length;
        for (uint256 i; i < length; ++i) {
            (, int256 price,, uint256 updatedAt0,) = sources[i].source.latestRoundData();

            if (price <= 0) revert InvalidPriceInt256(price);

            uint256 scaledPrice = getScaledPrice(uint256(price), sources[i].source.decimals());

            finalPrice += scaledPrice * sources[i].weight;
            weightSum += sources[i].weight;

            if (updatedAt0 > updatedAt) {
                updatedAt = updatedAt0;
            }
        }

        finalPrice /= weightSum;
    }

    // --- View Functions ---
    
    function decimals() external pure returns (uint8) {
        return TARGET_DIGITS;
    }

    function source(uint256 i) external view returns (address) {
        return address(sources[i].source);
    }

    function maxTimeThresholds(uint256 i) external view returns (uint256) {
        return sources[i].maxTimeThreshold;
    }

    function getScaledPrice(uint256 _rawPrice, uint8 _decimals) public pure returns (uint256) {
        uint256 scaledPrice;
        if (_decimals == TARGET_DIGITS) {
            scaledPrice = _rawPrice;
        } else if (_decimals < TARGET_DIGITS) {
            scaledPrice = _rawPrice * (10 ** (TARGET_DIGITS - _decimals));
        } else {
            scaledPrice = _rawPrice / (10 ** (_decimals - TARGET_DIGITS));
        }

        return scaledPrice;
    }

    // --- Retained for backward compatibility ---

    function updateMaxTimeThreshold(uint256) external pure {
        revert Deprecated();
    }

    function maxTimeThreshold() external pure returns (uint256) {
        revert Deprecated();
    }

    function source() external pure returns (address) {
        revert Deprecated();
    }

    // --- Owner Functions ---

    function setConfig(SourceConfig[] memory _sources) external onlyOwner {
        delete sources;
        uint256 length = _sources.length;
        for (uint256 i; i < length; ++i) {
            sources.push(_sources[i]);
        }
        emit ConfigSet(_sources);
    }
}
