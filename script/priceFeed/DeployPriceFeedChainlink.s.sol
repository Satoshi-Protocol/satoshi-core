// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PriceFeedChainlink} from "../../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {CHAINLINK_PRICE_FEED_SOURCE_ADDRESS} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedChainlink internal priceFeedChainlink;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AggregatorV3Interface source = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlink(source);
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
