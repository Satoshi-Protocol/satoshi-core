// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IPriceFeedAggregator, OracleRecord} from "../interfaces/core/IPriceFeedAggregator.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";

/**
 * @title PriceFeed Aggregator Contract (Upgradeable)
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/PriceFeed.sol
 *
 *        Handles multiple types of price feeds and converts their prices to 18-digit precision uint.
 */
contract PriceFeedAggregator is IPriceFeedAggregator, SatoshiOwnable, UUPSUpgradeable {
    // State ------------------------------------------------------------------------------------------------------------

    mapping(IERC20 => OracleRecord) public oracleRecords;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
    }

    // Admin routines ---------------------------------------------------------------------------------------------------

    function setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) external onlyOwner {
        _setPriceFeed(_token, _priceFeed);
    }

    function _setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) internal {
        if (address(_priceFeed) == address(0)) {
            revert InvalidPriceFeedAddress();
        }
        if (_priceFeed.fetchPrice() == uint256(0)) {
            revert InvalidFeedResponse(_priceFeed);
        }

        OracleRecord memory record = OracleRecord({priceFeed: _priceFeed, decimals: _priceFeed.decimals()});
        oracleRecords[_token] = record;

        emit NewOracleRegistered(_token, _priceFeed);
    }

    // Public functions -------------------------------------------------------------------------------------------------

    function fetchPrice(IERC20 _token) public returns (uint256) {
        OracleRecord memory oracle = oracleRecords[_token];
        uint256 targetDigits = IERC20Metadata(address(_token)).decimals();

        uint256 rawPrice = oracle.priceFeed.fetchPrice();
        uint8 decimals = oracle.decimals;

        uint256 scaledPrice;
        if (decimals == targetDigits) {
            scaledPrice = rawPrice;
        } else if (decimals < targetDigits) {
            scaledPrice = rawPrice * (10 ** (targetDigits - decimals));
        } else {
            scaledPrice = rawPrice / (10 ** (decimals - targetDigits));
        }
        return scaledPrice;
    }

    function fetchPriceUnsafe(IERC20 _token) external returns (uint256, uint256) {
        OracleRecord memory oracle = oracleRecords[_token];
        uint256 targetDigits = IERC20Metadata(address(_token)).decimals();

        (uint256 rawPrice, uint256 updatedAt) = oracle.priceFeed.fetchPriceUnsafe();
        uint8 decimals = oracle.decimals;

        uint256 scaledPrice;
        if (decimals == targetDigits) {
            scaledPrice = rawPrice;
        } else if (decimals < targetDigits) {
            scaledPrice = rawPrice * (10 ** (targetDigits - decimals));
        } else {
            scaledPrice = rawPrice / (10 ** (decimals - targetDigits));
        }
        return (scaledPrice, updatedAt);
    }
}
