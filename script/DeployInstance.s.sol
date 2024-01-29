// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {
    COLLATERAL_ADDRESS,
    PRICE_FEED_ADDRESS,
    CUSTOM_TROVE_MANAGER_IMPL,
    CUSTOM_SORTED_TROVES_IMPL,
    MINUTE_DECAY_FACTOR,
    REDEMPTION_FEE_FLOOR,
    MAX_REDEMPTION_FEE,
    BORROWING_FEE_FLOOR,
    MAX_BORROWING_FEE,
    INTEREST_RATE_IN_BPS,
    MAX_DEBT,
    MCR
} from "./DeployInstanceConfig.sol";

contract DeployInstanceScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    IFactory internal factory;
    address internal collateral;
    address internal priceFeed;
    address internal customTroveManagerImpl;
    address internal customSortedTrovesImpl;
    IFactory.DeploymentParams internal params;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        factory = IFactory(vm.envAddress("FACTORY_ADDRESS"));
        collateral = COLLATERAL_ADDRESS;
        priceFeed = PRICE_FEED_ADDRESS;
        customTroveManagerImpl = CUSTOM_TROVE_MANAGER_IMPL;
        customSortedTrovesImpl = CUSTOM_SORTED_TROVES_IMPL;
        params = IFactory.DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: INTEREST_RATE_IN_BPS,
            maxDebt: MAX_DEBT,
            MCR: MCR
        });
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        factory.deployNewInstance(collateral, priceFeed, customTroveManagerImpl, customSortedTrovesImpl, params);

        vm.stopBroadcast();
    }
}
