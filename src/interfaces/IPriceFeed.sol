// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPrismaOwnable} from "../interfaces/IPrismaOwnable.sol";
import {IAggregatorV3Interface} from "../interfaces/IAggregatorV3Interface.sol";

struct OracleRecord {
    IAggregatorV3Interface chainLinkOracle;
    uint8 decimals;
    uint32 heartbeat;
    bytes4 sharePriceSignature;
    uint8 sharePriceDecimals;
    bool isFeedWorking;
    bool isEthIndexed;
}

struct PriceRecord {
    uint96 scaledPrice;
    uint32 timestamp;
    uint32 lastUpdated;
    uint80 roundId;
}

struct FeedResponse {
    uint80 roundId;
    int256 answer;
    uint256 timestamp;
    bool success;
}

struct OracleSetup {
    IERC20 token;
    IAggregatorV3Interface chainlink;
    uint32 heartbeat;
    bytes4 sharePriceSignature;
    uint8 sharePriceDecimals;
    bool isEthIndexed;
}

interface IPriceFeed is IPrismaOwnable {
    event NewOracleRegistered(
        IERC20 indexed token, IAggregatorV3Interface indexed chainlinkAggregator, bool indexed isEthIndexed
    );
    event PriceFeedStatusUpdated(IERC20 indexed token, address indexed oracle, bool indexed isWorking);
    event PriceRecordUpdated(IERC20 indexed token, uint256 indexed _price);

    // Custom Errors --------------------------------------------------------------------------------------------------

    error PriceFeed__InvalidFeedResponseError(IERC20 token);
    error PriceFeed__FeedFrozenError(IERC20 token);
    error PriceFeed__UnknownFeedError(IERC20 token);
    error PriceFeed__HeartbeatOutOfBoundsError();

    function fetchPrice(IERC20 _token) external returns (uint256);

    function setOracle(
        IERC20 _token,
        IAggregatorV3Interface _chainlinkOracle,
        uint32 _heartbeat,
        bytes4 sharePriceSignature,
        uint8 sharePriceDecimals,
        bool _isEthIndexed
    ) external;

    function MAX_PRICE_DEVIATION_FROM_PREVIOUS_ROUND() external view returns (uint256);

    function TARGET_DIGITS() external view returns (uint256);

    function oracleRecords(IERC20)
        external
        view
        returns (
            IAggregatorV3Interface chainLinkOracle,
            uint8 decimals,
            uint32 heartbeat,
            bytes4 sharePriceSignature,
            uint8 sharePriceDecimals,
            bool isFeedWorking,
            bool isEthIndexed
        );

    function priceRecords(IERC20)
        external
        view
        returns (uint96 scaledPrice, uint32 timestamp, uint32 lastUpdated, uint80 roundId);
}
