// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedChainlinkAggregator} from "../../src/dependencies/priceFeed/PriceFeedChainlinkAggregator.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SourceConfig} from "../../src/interfaces/dependencies/IPriceFeed.sol";
import {
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0,
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1,
    SATOSHI_CORE_ADDRESS,
    CHAINLINK_MAX_TIME_THRESHOLD_0,
    CHAINLINK_MAX_TIME_THRESHOLD_1,
    CHAINLINK_SOURCE_WEIGHT_0,
    CHAINLINK_SOURCE_WEIGHT_1
} from "./DeployPriceFeedConfig.sol";

contract SetConfigPriceFeedChainlinkAggregatorScript is Script {
    PriceFeedChainlinkAggregator internal priceFeedChainlink;
    uint256 internal OWNER_PRIVATE_KEY;
    address public owner;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        owner = vm.addr(OWNER_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        SourceConfig[] memory sources = new SourceConfig[](2);
        sources[0] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_0,
            weight: CHAINLINK_SOURCE_WEIGHT_0
        });
        sources[1] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_1,
            weight: CHAINLINK_SOURCE_WEIGHT_1
        });

        priceFeedChainlink = PriceFeedChainlinkAggregator(0xE3cD7A8AEb9c1305162b216aB93Ef98EfC0e451c);
        priceFeedChainlink.setConfig(sources);
        assert(priceFeedChainlink.fetchPrice()/1e18 > 60000);
        console.log(priceFeedChainlink.fetchPrice()/1e18);

        vm.stopBroadcast();
    }
}
