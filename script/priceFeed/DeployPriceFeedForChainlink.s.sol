// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {PriceFeedForChainlink} from "../../src/dependencies/priceFeed/PriceFeedForChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/AggregatorV3Interface.sol";
import {ORIGINAL_PRICE_FEED_SOURCE_ADDRESS} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedForChainlinkScript is Script {
    PriceFeedForChainlink internal priceFeedForChainlink;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        AggregatorV3Interface originalPriceFeed = AggregatorV3Interface(ORIGINAL_PRICE_FEED_SOURCE_ADDRESS);
        priceFeedForChainlink = new PriceFeedForChainlink(originalPriceFeed);
        assert(priceFeedForChainlink.fetchPrice() > 0);
        console.log("PriceFeedForChainlink deployed at:", address(priceFeedForChainlink));

        vm.stopBroadcast();
    }
}
