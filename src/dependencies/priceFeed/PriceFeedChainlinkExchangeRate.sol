// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed, SourceConfig} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Convert data from interface of Chainlink to Satoshi's IPriceFeed
 *        Price * Exchange Rate
 */
contract PriceFeedChainlinkExchangeRate is IPriceFeed, SatoshiOwnable {
    uint8 public constant TARGET_DIGITS = 18;
    SourceConfig[] public sources;

    constructor(ISatoshiCore _satoshiCore, SourceConfig[] memory _sources) {
        __SatoshiOwnable_init(_satoshiCore);
        require(_sources.length == 2, "PriceFeedChainlinkExchangeRate: Invalid sources length");
        for (uint256 i; i < _sources.length; ++i) {
            sources.push(_sources[i]);
            emit ConfigSet(_sources[i]);
        }
    }

    // --- External Functions ---
    function fetchPrice() external view returns (uint256 finalPrice) {
        // fetch the price
        (, int256 price,, uint256 updatedAt,) = sources[0].source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);
        if (block.timestamp - updatedAt > sources[0].maxTimeThreshold) {
            revert PriceTooOld();
        }

        uint256 scaledPrice = getScaledPrice(uint256(price), sources[i].source.decimals());

        // fetch the exchange rate
        (, int256 rate,, uint256 rateUpdatedAt,) = sources[1].source.latestRoundData();
        if (rate <= 0) revert InvalidPriceInt256(rate);
        if (block.timestamp - updatedAt > sources[1].maxTimeThreshold) {
            revert PriceTooOld();
        }

        uint256 scaledRate = getScaledPrice(uint256(rate), sources[1].source.decimals());

        finalPrice = scaledPrice * scaledRate / 10 ** TARGET_DIGITS;

        return finalPrice;
    }

    function fetchPriceUnsafe() external view returns (uint256, uint256) {
        // fetch the price
        (, int256 price,, uint256 updatedAt,) = sources[0].source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);

        uint256 scaledPrice = getScaledPrice(uint256(price), sources[i].source.decimals());

        // fetch the exchange rate
        (, int256 rate,,,) = sources[1].source.latestRoundData();
        if (rate <= 0) revert InvalidPriceInt256(rate);

        uint256 scaledRate = getScaledPrice(uint256(rate), sources[1].source.decimals());

        finalPrice = scaledPrice * scaledRate / 10 ** TARGET_DIGITS;

        return (finalPrice, updatedAt);
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
        require(_sources.length == 2, "PriceFeedChainlinkExchangeRate: Invalid sources length");
        delete sources;
        uint256 length = _sources.length;
        for (uint256 i; i < length; ++i) {
            sources.push(_sources[i]);
            emit ConfigSet(_sources[i]);
        }
    }
}
