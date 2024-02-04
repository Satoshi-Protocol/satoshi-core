// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {AggregatorV3Interface} from "../src/interfaces/dependencies/AggregatorV3Interface.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {DeploymentParams} from "../src/core/Factory.sol";
import {
    FACTORY_ADDRESS,
    PRICE_FEED_AGGREGATOR_ADDRESS,
    PRICE_FEED_ADDRESS,
    COLLATERAL_ADDRESS,
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
    IERC20 internal collateral;
    IPriceFeedAggregator internal priceFeedAggregator;
    IPriceFeed internal priceFeed;
    DeploymentParams internal deploymentParams;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        factory = IFactory(FACTORY_ADDRESS);
        collateral = IERC20(COLLATERAL_ADDRESS);
        priceFeedAggregator = IPriceFeedAggregator(PRICE_FEED_AGGREGATOR_ADDRESS);
        priceFeed = IPriceFeed(PRICE_FEED_ADDRESS);
        deploymentParams = DeploymentParams({
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

        priceFeedAggregator.setPriceFeed(collateral, priceFeed);
        DeploymentParams memory params = deploymentParams;
        factory.deployNewInstance(collateral, priceFeed, params);

        vm.stopBroadcast();
    }
}
