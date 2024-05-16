// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {IPriceFeed} from "../dependencies/IPriceFeed.sol";

struct OracleRecord {
    IPriceFeed priceFeed;
    uint8 decimals;
}

interface IPriceFeedAggregator is ISatoshiOwnable {
    event NewOracleRegistered(IERC20 indexed token, IPriceFeed indexed priceFeed);

    // Custom Errors --------------------------------------------------------------------------------------------------

    error InvalidPriceFeedAddress();
    error InvalidFeedResponse(IPriceFeed priceFeed);

    function initialize(ISatoshiCore _satoshiCore) external;

    function fetchPrice(IERC20 _token) external returns (uint256);

    function setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) external;

    function oracleRecords(IERC20) external view returns (IPriceFeed priceFeed, uint8 decimals);
}
