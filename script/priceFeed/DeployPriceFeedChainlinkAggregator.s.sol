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
    CHAINLINK_SOURCE_WEIGHT_0,
    CHAINLINK_SOURCE_WEIGHT_1
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
        uint256[] memory weight = new uint256[](2);
        weight[0] = CHAINLINK_SOURCE_WEIGHT_0;
        weight[1] = CHAINLINK_SOURCE_WEIGHT_1;

        AggregatorV3Interface[] memory sources = new AggregatorV3Interface[](2);
        sources[0] = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0);
        sources[1] = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1);

        uint256[] memory threshold = new uint256[](2);
        threshold[0] = CHAINLINK_MAX_TIME_THRESHOLD;
        threshold[1] = CHAINLINK_MAX_TIME_THRESHOLD;

        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlinkAggregator(sources, satoshiCore, threshold, weight);
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
