// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IAggregatorV3Interface} from "../src/interfaces/IAggregatorV3Interface.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";
import {ITroveManager} from "../src/interfaces/ITroveManager.sol";
import {ISortedTroves} from "../src/interfaces/ISortedTroves.sol";
import {DeploymentParams} from "../src/core/Factory.sol";
import {
    FACTORY_ADDRESS,
    PRICE_FEED_ADDRESS,
    COLLATERAL_ADDRESS,
    ORACLE_ADDRESS,
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
    IERC20 internal collateral;
    IPriceFeed internal priceFeed;
    IAggregatorV3Interface internal oracle;
    ITroveManager internal customTroveManagerImpl;
    ISortedTroves internal customSortedTrovesImpl;
    DeploymentParams internal deploymentParams;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        factory = IFactory(FACTORY_ADDRESS);
        collateral = IERC20(COLLATERAL_ADDRESS);
        priceFeed = IPriceFeed(PRICE_FEED_ADDRESS);
        oracle = IAggregatorV3Interface(ORACLE_ADDRESS);
        customTroveManagerImpl = ITroveManager(CUSTOM_TROVE_MANAGER_IMPL);
        customSortedTrovesImpl = ISortedTroves(CUSTOM_SORTED_TROVES_IMPL);
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

    // IERC20 _token,
    //         IAggregatorV3Interface _chainlinkOracle,
    //         uint32 _heartbeat,
    //         bytes4 sharePriceSignature,
    //         uint8 sharePriceDecimals,
    //         bool _isEthIndexed
    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        priceFeed.setOracle(collateral, oracle, 10000, 0, 0, false);
        DeploymentParams memory params = deploymentParams;
        factory.deployNewInstance(collateral, priceFeed, customTroveManagerImpl, customSortedTrovesImpl, params);

        vm.stopBroadcast();
    }
}
