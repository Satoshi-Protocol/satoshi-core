// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {PrismaCore} from "../src/core/PrismaCore.sol";
import {PriceFeed} from "../src/core/PriceFeed.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {Deployment} from "../src/core/helpers/Deployment.sol";
import {PRISMA_CORE_OWNER, PRISMA_CORE_GUARDIAN, PRISMA_CORE_PRICE_FEED, PRISMA_CORE_FEE_RECEIVER, PRICE_FEED_ETH_FEED} from "./DeployConfig.sol";

contract DeployScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    bytes32 internal DEPLOYMENT_SALT;
    address internal computedPrismaCoreAddr;
    Deployment public deployment;
    SortedTroves public sortedTroves;
    PrismaCore public prismaCore;
    PriceFeed public priceFeed;
    GasPool public gasPool;
    
    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        DEPLOYMENT_SALT = bytes32(vm.envUint("DEPLOYMENT_SALT"));
        computedPrismaCoreAddr = Create2.computeAddress(DEPLOYMENT_SALT, keccak256(type(PrismaCore).creationCode));
        deployment = new Deployment(DEPLOYMENT_SALT);
    }

    function run() public {
        vm.startBroadcast();

        // empty array
        PriceFeed.OracleSetup[] memory oracleSetups = new PriceFeed.OracleSetup[](0);

        deployment.deployPriceFeed(PRICE_FEED_ETH_FEED, oracleSetups);
        // // Deploy `PriceFeed.sol`
        // priceFeed = new PriceFeed(computedPrismaCoreAddr, PRICE_FEED_ETH_FEED, oracleSetups);

        // // Deploy `PrismaCore.sol`
        // prismaCore = new PrismaCore{salt: DEPLOYMENT_SALT}(
        //     PRISMA_CORE_OWNER,
        //     PRISMA_CORE_GUARDIAN,
        //     address(priceFeed),
        //     PRISMA_CORE_FEE_RECEIVER
        // );

        // console.log("PrismaCore computed at: ", computedPrismaCoreAddr);
        // console.log("PrismaCore deployed at: ", address(prismaCore));

        vm.stopBroadcast();
    }
}
