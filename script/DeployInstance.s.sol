// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {DeploymentParams} from "../src/core/Factory.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../src/interfaces/core/IOSHIToken.sol";
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
    MCR,
    REWARD_RATE,
    OSHI_TOKEN_ADDRESS,
    TM_ALLOCATION,
    TM_CLAIM_START_TIME
} from "./DeployInstanceConfig.sol";

contract DeployInstanceScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    IFactory internal factory;
    IERC20 internal collateral;
    IPriceFeedAggregator internal priceFeedAggregator;
    IPriceFeed internal priceFeed;
    IRewardManager internal rewardManager;
    ICommunityIssuance internal communityIssuance;
    ISatoshiCore internal satoshiCore;
    IDebtToken internal debtToken;
    IOSHIToken internal oshiToken;
    DeploymentParams internal deploymentParams;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        factory = IFactory(FACTORY_ADDRESS);
        collateral = IERC20(COLLATERAL_ADDRESS);
        priceFeedAggregator = IPriceFeedAggregator(PRICE_FEED_AGGREGATOR_ADDRESS);
        priceFeed = IPriceFeed(PRICE_FEED_ADDRESS);
        oshiToken = IOSHIToken(OSHI_TOKEN_ADDRESS);
        communityIssuance = factory.communityIssuance();
        assert(address(communityIssuance) != address(0));
        debtToken = factory.debtToken();
        assert(address(debtToken) != address(0));
        rewardManager = factory.rewardManager();
        assert(address(rewardManager) != address(0));
        deploymentParams = DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: INTEREST_RATE_IN_BPS,
            maxDebt: MAX_DEBT,
            MCR: MCR,
            rewardRate: REWARD_RATE,
            OSHIAllocation: TM_ALLOCATION,
            claimStartTime: TM_CLAIM_START_TIME
        });
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        priceFeedAggregator.setPriceFeed(collateral, priceFeed);
        DeploymentParams memory params = deploymentParams;
        // (ISortedTroves sortedTrovesBeaconProxy, ITroveManager troveManagerBeaconProxy) =
        factory.deployNewInstance(collateral, priceFeed, params);

        uint256 troveManagerCount = factory.troveManagerCount();
        ITroveManager troveManagerBeaconProxy = factory.troveManagers(troveManagerCount - 1);
        ISortedTroves sortedTrovesBeaconProxy = troveManagerBeaconProxy.sortedTroves();

        // set reward manager settings
        rewardManager.registerTroveManager(troveManagerBeaconProxy);

        // set community issuance allocation & addresses
        _setCommunityIssuanceAllocation(address(troveManagerBeaconProxy), params.OSHIAllocation);

        console.log("SortedTrovesBeaconProxy: address:", address(sortedTrovesBeaconProxy));
        console.log("TroveManagerBeaconProxy: address:", address(troveManagerBeaconProxy));

        vm.stopBroadcast();
    }

    function _setCommunityIssuanceAllocation(address troveManagerBeaconProxy, uint256 allocation) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = troveManagerBeaconProxy;
        uint256[] memory _amount = new uint256[](1);
        _amount[0] = allocation;
        communityIssuance.setAllocated(_recipients, _amount);
    }
}
