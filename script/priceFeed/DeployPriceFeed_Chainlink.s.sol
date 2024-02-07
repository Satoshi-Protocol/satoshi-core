// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PriceFeedChainlink} from "../../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/AggregatorV3Interface.sol";
import {ORIGINAL_PRICE_FEED_SOURCE_ADDRESS} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedChainlink internal priceFeedChainlink;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AggregatorV3Interface originalPriceFeed = AggregatorV3Interface(ORIGINAL_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlink(originalPriceFeed);
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
