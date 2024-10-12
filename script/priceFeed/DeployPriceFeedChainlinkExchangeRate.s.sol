// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedChainlinkExchangeRate} from "../../src/dependencies/priceFeed/PriceFeedChainlinkExchangeRate.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {SourceConfig} from "../../src/interfaces/dependencies/IPriceFeed.sol";
import {
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0,
    CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1,
    SATOSHI_CORE_ADDRESS,
    CHAINLINK_MAX_TIME_THRESHOLD_0,
    CHAINLINK_MAX_TIME_THRESHOLD_1
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkExchangeRateScript is Script {
    PriceFeedChainlinkExchangeRate internal priceFeedChainlink;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);
        SourceConfig[] memory sources = new SourceConfig[](2);
        sources[0] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_0),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_0,
            weight: 0
        });
        sources[1] = SourceConfig({
            source: AggregatorV3Interface(CHAINLINK_PRICE_FEED_SOURCE_ADDRESS_1),
            maxTimeThreshold: CHAINLINK_MAX_TIME_THRESHOLD_1,
            weight: 0
        });

        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedChainlink = new PriceFeedChainlinkExchangeRate(satoshiCore, sources);
        (, int256 answer,,,) = priceFeedChainlink.latestRoundData();
        assert(answer > 0);
        console.log("PriceFeedChainlink deployed at:", address(priceFeedChainlink));

        vm.stopBroadcast();
    }
}
