// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IPrismaOwnable} from "../dependencies/IPrismaOwnable.sol";
import {IPrismaCore} from "../core/IPrismaCore.sol";
import {IPriceFeed} from "../dependencies/IPriceFeed.sol";

struct OracleRecord {
    IPriceFeed priceFeed;
    uint8 decimals;
}

struct OracleSetup {
    IERC20 token;
    IPriceFeed priceFeed;
}

interface IPriceFeedAggregator is IPrismaOwnable {
    event NewOracleRegistered(IERC20 indexed token, IPriceFeed indexed priceFeed);

    // Custom Errors --------------------------------------------------------------------------------------------------

    error InvalidPriceFeedAddress();
    error InvalidFeedResponse(IPriceFeed priceFeed);

    function initialize(IPrismaCore _prismaCore, IPriceFeed _nativeTokenFeed, OracleSetup[] memory _oracles)
        external;

    function fetchPrice(IERC20 _token) external returns (uint256);

    function setPriceFeed(IERC20 _token, IPriceFeed _priceFeed) external;

    function oracleRecords(IERC20) external view returns (IPriceFeed priceFeed, uint8 decimals);
}
