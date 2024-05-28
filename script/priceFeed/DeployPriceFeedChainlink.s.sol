// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedChainlink} from "../../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {CHAINLINK_PRICE_FEED_SOURCE_ADDRESS, SATOSHI_CORE_ADDRESS} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedChainlink internal priceFeedChainlink;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        AggregatorV3Interface source = AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlink(source, satoshiCore);
        assert(priceFeedChainlink.fetchPrice() > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
