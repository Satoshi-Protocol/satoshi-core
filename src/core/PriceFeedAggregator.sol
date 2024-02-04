// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {PrismaOwnable} from "../dependencies/PrismaOwnable.sol";
import {IPrismaCore} from "../interfaces/core/IPrismaCore.sol";
import {IPriceFeedAggregator, OracleRecord, OracleSetup} from "../interfaces/core/IPriceFeedAggregator.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";

contract PriceFeedAggregator is IPriceFeedAggregator, PrismaOwnable, UUPSUpgradeable {
    // Used to convert the raw price to an 18-digit precision uint
    uint256 public constant TARGET_DIGITS = 18;

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

    function initialize(IPrismaCore _prismaCore, IPriceFeed _nativeTokenPriceFeed, OracleSetup[] memory _oracles)
        external
        initializer
    {
        __UUPSUpgradeable_init_unchained();
        __PrismaOwnable_init(_prismaCore);
        _setPriceFeed(IERC20(address(0)), _nativeTokenPriceFeed);

        for (uint256 i = 0; i < _oracles.length; i++) {
            OracleSetup memory o = _oracles[i];
            _setPriceFeed(o.token, o.priceFeed);
        }
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

    function fetchPrice(IERC20 _token) public view returns (uint256) {
        OracleRecord memory oracle = oracleRecords[_token];

        uint256 rawPrice = oracle.priceFeed.fetchPrice();
        uint8 decimals = oracle.decimals;

        uint256 scaledPrice;
        if (decimals == TARGET_DIGITS) {
            scaledPrice = rawPrice;
        } else if (decimals < TARGET_DIGITS) {
            scaledPrice = rawPrice * (10 ** (TARGET_DIGITS - decimals));
        } else {
            scaledPrice = rawPrice / (10 ** (decimals - TARGET_DIGITS));
        }
        return scaledPrice;
    }
}
