// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {ISupraSValueFeed} from "../../src/interfaces/dependencies/priceFeed/ISupraSValueFeed.sol";
import {PriceFeedSupraOracle} from "../../src/dependencies/priceFeed/PriceFeedSupraOracle.sol";
import {
    SATOSHI_CORE_ADDRESS,
    SUPRA_MAX_TIME_THRESHOLD,
    SUPRA_ORACLE_PAIR_INDEX,
    SUPRA_ORACLE_PRICE_FEED_DECIMAL,
    SUPRA_ORACLE_PRICE_FEED_SOURCE_ADDRESS
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedSupraScript is Script {
    PriceFeedSupraOracle internal priceFeedSupraOracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        ISupraSValueFeed source = ISupraSValueFeed(SUPRA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedAPI3Oracle =
            new PriceFeedAPI3Oracle(source, API3_ORACLE_PRICE_FEED_DECIMAL, satoshiCore, API3_MAX_TIME_THRESHOLD);
        assert(priceFeedAPI3Oracle.fetchPrice() > 0);
        console.log("PriceFeedAPI3Oracle deployed at:", address(priceFeedAPI3Oracle));

        vm.stopBroadcast();
    }
}
