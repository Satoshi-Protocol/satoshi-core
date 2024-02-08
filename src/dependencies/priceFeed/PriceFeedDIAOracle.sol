// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {IDIAOracleV2} from "../../interfaces/dependencies/priceFeed/IDIAOracleV2.sol";

contract PriceFeedDIAOracle is IPriceFeed {
    IDIAOracleV2 internal immutable _source;
    uint8 internal immutable _decimals;
    string internal _key;

    constructor(IDIAOracleV2 source_, uint8 decimals_, string memory key_) {
        _source = source_;
        _decimals = decimals_;
        _key = key_;
    }

    function fetchPrice() external returns (uint256) {
        (uint128 price,) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);
        return uint256(price);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }
}
