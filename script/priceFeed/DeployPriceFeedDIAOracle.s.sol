// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedDIAOracle} from "../../src/dependencies/priceFeed/PriceFeedDIAOracle.sol";
import {IDIAOracleV2} from "../../src/interfaces/dependencies/priceFeed/IDIAOracleV2.sol";
import {
    SATOSHI_CORE_ADDRESS,
    DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS,
    DIA_ORACLE_PRICE_FEED_DECIMALS,
    DIA_ORACLE_PRICE_FEED_KEY
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedChainlinkScript is Script {
    PriceFeedDIAOracle internal priceFeedDIAOracle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        IDIAOracleV2 source = IDIAOracleV2(DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        priceFeedDIAOracle =
            new PriceFeedDIAOracle(source, DIA_ORACLE_PRICE_FEED_DECIMALS, DIA_ORACLE_PRICE_FEED_KEY, satoshiCore);
        assert(priceFeedDIAOracle.fetchPrice() > 0);
        console.log("PriceFeedDIAOracle deployed at:", address(priceFeedDIAOracle));

        vm.stopBroadcast();
    }
}
