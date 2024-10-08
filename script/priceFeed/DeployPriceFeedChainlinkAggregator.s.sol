// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedChainlinkAggregator} from "../../src/dependencies/priceFeed/PriceFeedChainlinkAggregator.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0,
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1,
    SATOSHI_CORE_ADDRESS,
    CHAINLINK_MAX_TIME_THRESHOLD,
    CHAINLINK_SOURCE_RATIO_0,
    CHAINLINK_SOURCE_RATIO_1
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkAggregatorScript is Script {
    PriceFeedChainlinkAggregator internal priceFeedChainlink;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        AggregatorV3Interface source0 = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0);
        AggregatorV3Interface source1 = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlinkAggregator(
            source0,
            source1,
            satoshiCore,
            CHAINLINK_MAX_TIME_THRESHOLD,
            CHAINLINK_SOURCE_RATIO_0,
            CHAINLINK_SOURCE_RATIO_1
        );
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
