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
    uint256 public maxTimeThreshold;

    constructor(
        IPyth pyth_,
        uint8 decimals_,
        ISatoshiCore _satoshiCore,
        bytes32 priceID_,
        uint256 _maxTimeThreshold
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        pyth = pyth_;
        _decimals = decimals_;
        priceID = priceID_;
        maxTimeThreshold = _maxTimeThreshold;

        emit PriceIDUpdated(priceID_);
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }

    function updateFeeds(bytes[] calldata priceUpdateData) public payable {
        // Update the prices to the latest available values and pay the required fee for it. The `priceUpdateData` data
        // should be retrieved from our off-chain Price Service API using the `pyth-evm-js` package.
        // See section "How Pyth Works on EVM Chains" below for more information.
        uint fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(priceUpdateData);

        // refund remaining eth
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        if (!success) revert RefundFailed();
    }

    function fetchPrice() external view returns (uint256) {
        PythStructs.Price memory pythData = IPyth(pyth).getPriceNoOlderThan(priceID, maxTimeThreshold);
        if (pythData.price <= 0) {
            revert InvalidPriceInt256(pythData.price);
        }
        uint256 price = uint64(pythData.price);

        return price;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function setPriceID(bytes32 priceID_) external onlyOwner {
        priceID = priceID_;
        emit PriceIDUpdated(priceID_);
    }

    function updateMaxTimeThreshold(uint256 _maxTimeThreshold) external onlyOwner {
        maxTimeThreshold = _maxTimeThreshold;
        emit MaxTimeThresholdUpdated(_maxTimeThreshold);
    }
}
