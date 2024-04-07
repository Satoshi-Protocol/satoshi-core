// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {PriceFeedWstBTCWithDIAOracle, IWstBTCPartial} from "../../src/dependencies/priceFeed/PriceFeedWstBTCWithDIAOracle.sol";
import {IDIAOracleV2} from "../../src/interfaces/dependencies/priceFeed/IDIAOracleV2.sol";
import {
    SATOSHI_CORE_ADDRESS,
    DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS,
    DIA_ORACLE_PRICE_FEED_DECIMALS,
    DIA_ORACLE_PRICE_FEED_KEY,
    DIA_MAX_TIME_THRESHOLD,
    WSTBTC_ADDRESS
} from "./DeployPriceFeedConfig.sol";

contract DeployPriceFeedWSTBTCScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    PriceFeedWstBTCWithDIAOracle internal priceFeedWstBTCWithDIAOracle;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        IDIAOracleV2 source = IDIAOracleV2(DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS);
        ISatoshiCore satoshiCore = ISatoshiCore(SATOSHI_CORE_ADDRESS);
        IWstBTCPartial wstBTC = IWstBTCPartial(WSTBTC_ADDRESS);
        priceFeedWstBTCWithDIAOracle = new PriceFeedWstBTCWithDIAOracle(
            source, DIA_ORACLE_PRICE_FEED_DECIMALS, DIA_ORACLE_PRICE_FEED_KEY, satoshiCore, DIA_MAX_TIME_THRESHOLD, wstBTC
        );
        assert(priceFeedWstBTCWithDIAOracle.fetchPrice() > 0);
        console.log("wstbtc price", priceFeedWstBTCWithDIAOracle.fetchPrice());
        console.log("PriceFeedWstBTCWithDIAOracle deployed at:", address(priceFeedWstBTCWithDIAOracle));

        vm.stopBroadcast();
    }
}
