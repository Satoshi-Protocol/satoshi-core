// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed, SourceConfig} from "../../interfaces/dependencies/IPriceFeed.sol";
import {AggregatorV3Interface} from "../../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title PriceFeed Contract to integrate with Chainlink
 *        Contract to integrate Chainlink price feeds with exchange rate conversion
 *        Price * Exchange Rate
 */
contract PriceFeedChainlinkExchangeRate is SatoshiOwnable {
    /// @notice Thrown when the price returned by Chainlink is non-positive
    /// @param price The invalid price value
    error InvalidPriceInt256(int256 price);

    /// @notice Thrown when the price data is older than the maximum allowed threshold
    error PriceTooOld();

    /// @notice Thrown when attempting to use a deprecated function
    error Deprecated();

    /// @notice Emitted when a new source configuration is set
    /// @param sources The new source configuration
    event ConfigSet(SourceConfig sources);

    /// @notice The target number of decimal places for price calculations
    uint8 public constant TARGET_DIGITS = 18;

    /// @notice Array of source configurations
    SourceConfig[] public sources;

    /// @notice Initializes the contract with Satoshi core and price sources
    /// @param _satoshiCore The address of the Satoshi core contract
    /// @param _sources Array of source configurations (must contain exactly 2 elements, the first one is the price and the second one is the exchange rate)
    constructor(ISatoshiCore _satoshiCore, SourceConfig[] memory _sources) {
        __SatoshiOwnable_init(_satoshiCore);
        require(_sources.length == 2, "PriceFeedChainlinkExchangeRate: Invalid sources length");
        for (uint256 i; i < _sources.length; ++i) {
            sources.push(_sources[i]);
            emit ConfigSet(_sources[i]);
        }
    }

    // --- External Functions ---

    /// @notice Fetches the latest price data, applying the exchange rate
    /// @return Tuple containing roundId, price, startedAt, updatedAt, answeredInRound
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        // fetch the price
        (, int256 price,, uint256 updatedAt,) = sources[0].source.latestRoundData();
        if (price <= 0) revert InvalidPriceInt256(price);

        uint256 scaledPrice = getScaledPrice(uint256(price), sources[0].source.decimals());

        // fetch the exchange rate
        (, int256 rate,, uint256 rateUpdatedAt,) = sources[1].source.latestRoundData();
        if (rate <= 0) revert InvalidPriceInt256(rate);
        if (block.timestamp - rateUpdatedAt > sources[1].maxTimeThreshold) {
            revert PriceTooOld();
        }

        uint256 scaledRate = getScaledPrice(uint256(rate), sources[1].source.decimals());

        uint256 finalPrice = Math.mulDiv(scaledPrice, scaledRate, 10 ** TARGET_DIGITS);

        return (0, int256(finalPrice), 0, updatedAt, 0);
    }

    // --- View Functions ---

    /// @notice Returns the decimals used in price calculations
    /// @return The decimals
    function decimals() external pure returns (uint8) {
        return TARGET_DIGITS;
    }

    /// @notice Returns the address of a price source
    /// @param i The index of the source (0 for price, 1 for exchange rate)
    /// @return The address of the price source
    function source(uint256 i) external view returns (address) {
        return address(sources[i].source);
    }

    /// @notice Returns the maximum time threshold for a price source
    /// @param i The index of the source (0 for price, 1 for exchange rate)
    /// @return The maximum time threshold in seconds
    function maxTimeThresholds(uint256 i) external view returns (uint256) {
        return sources[i].maxTimeThreshold;
    }

    /// @notice Scales a raw price to the target number of decimals
    /// @param _rawPrice The raw price from the price feed
    /// @param _decimals The decimals in the raw price
    /// @return The scaled price with TARGET_DIGITS
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

    // --- Owner Functions ---

    /// @notice Allows the owner to update the source configurations
    /// @param _sources New array of source configurations (must contain exactly 2 elements)
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
