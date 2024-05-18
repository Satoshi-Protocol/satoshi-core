// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedAPI3Oracle} from "../../src/dependencies/priceFeed/PriceFeedAPI3Oracle.sol";
import {IProxy} from "@api3/contracts/api3-server-v1/proxies/interfaces/IProxy.sol";
import {
    SATOSHI_CORE_ADDRESS,
    API3_MAX_TIME_THRESHOLD,
    API3_ORACLE_PRICE_FEED_DECIMAL,
    API3_ORACLE_PRICE_FEED_SOURCE_ADDRESS
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedAPI3Script is Script {
    PriceFeedAPI3Oracle internal priceFeedAPI3Oracle;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IProxy source = IProxy(API3_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedAPI3Oracle =
            new PriceFeedAPI3Oracle(source, API3_ORACLE_PRICE_FEED_DECIMAL, satoshiCore, API3_MAX_TIME_THRESHOLD);
        assert(priceFeedAPI3Oracle.fetchPrice() > 0);
        console.log("PriceFeedAPI3Oracle deployed at:", address(priceFeedAPI3Oracle));

        vm.stopBroadcast();
    }
}
