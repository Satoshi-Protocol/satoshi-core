// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {IDIAOracleV2} from "../../interfaces/dependencies/priceFeed/IDIAOracleV2.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";

contract PriceFeedDIAOracle is IPriceFeed, SatoshiOwnable {
    IDIAOracleV2 internal immutable _source;
    uint8 internal immutable _decimals;
    string internal _key;
    uint256 public diaMaxTimeThreshold;

    constructor(IDIAOracleV2 source_, uint8 decimals_, string memory key_) {
        _source = source_;
        _decimals = decimals_;
        _key = key_;
        diaMaxTimeThreshold = 86400;
    }

    function fetchPrice() external returns (uint256) {
        (uint128 price, uint128 lastUpdated) = _source.getValue(_key);
        if (price == 0) revert InvalidPriceUInt128(price);
        if (block.timestamp - lastUpdated > diaMaxTimeThreshold) {
            revert PriceTooOld();
        }
        return uint256(price);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function updateDIAParams(uint128 _maxTime) public onlyOwner {
        if (_maxTime <= 120) {
            revert InvalidTime();
        }

        diaMaxTimeThreshold = _maxTime;
        emit DIAParamsUpdated(_maxTime);
    }
}
