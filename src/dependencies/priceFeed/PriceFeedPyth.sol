// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeedPyth} from "../../interfaces/dependencies/IPriceFeedPyth.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title PriceFeed Contract to integrate with DIA Oracle
 *        Convert data from interface of DIA Oracle to Satoshi's IPriceFeed
 */
contract PriceFeedPythOracle is IPriceFeedPyth, SatoshiOwnable {
    IPyth pyth;
    bytes32 priceID;
    uint8 internal immutable _decimals;
    string internal _key;

    constructor(
        IPyth pyth_,
        uint8 decimals_,
        ISatoshiCore _satoshiCore,
        bytes32 priceID_
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        pyth = pyth_;
        _decimals = decimals_;
        priceID = priceID_;
    }

    function fetchPrice(bytes[] calldata priceUpdateData) external returns (uint256) {
        uint fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{ value: fee }(priceUpdateData);
        PythStructs.Price memory pythData = IPyth(pyth).getPrice(priceID);
        require(pythData.price > 0, "PriceFeedPythOracle: Price is not valid");
        uint256 normalizedPrice = uint64(pythData.price);

        return normalizedPrice;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function setPriceID(bytes32 priceID_) external onlyOwner {
        priceID = priceID_;
        emit PriceIDUpdated(priceID_);
    }
}
