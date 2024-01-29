// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {IPrismaCore} from "../src/interfaces/IPrismaCore.sol";
import {IBorrowerOperations} from "../src/interfaces/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/IStabilityPool.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {PrismaCore} from "../src/core/PrismaCore.sol";
import {PriceFeed} from "../src/core/PriceFeed.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";
import {
    PRISMA_CORE_OWNER,
    PRISMA_CORE_GUARDIAN,
    PRISMA_CORE_FEE_RECEIVER,
    PRICE_FEED_ETH_FEED,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    DEBT_TOKEN_LAYER_ZERO_END_POINT,
    BO_MIN_NET_DEBT,
    GAS_COMPENSATION
} from "./DeployConfig.sol";

contract DeployScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address internal deployer;
    uint64 internal nonce;
    SortedTroves public sortedTroves;
    PrismaCore public prismaCore;
    PriceFeed public priceFeed;
    GasPool public gasPool;
    BorrowerOperations public borrowerOperations;
    DebtToken public debtToken;
    LiquidationManager public liquidationManager;
    StabilityPool public stabilityPool;
    TroveManager public troveManager;
    Factory public factory;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
        nonce = vm.getNonce(deployer);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        console.log("start nonce");
        console.log(nonce);

        address computedSortedTrovesAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedPriceFeedAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedPrismaCoreAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedGasPoolAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedBorrowerOperationsAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedDebtTokenAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedLiquidationManagerAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedStabilityPoolAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedTroveManagerAddr = vm.computeCreateAddress(deployer, nonce);
        ++nonce;
        address computedFactoryAddr = vm.computeCreateAddress(deployer, nonce);

        // Deploy `SortedTroves.sol`
        sortedTroves = new SortedTroves();
        console.log("SortedTroves computed at: ", computedSortedTrovesAddr);
        console.log("SortedTroves deployed at: ", address(sortedTroves));
        assert(computedSortedTrovesAddr == address(sortedTroves));

        // empty array
        PriceFeed.OracleSetup[] memory oracleSetups = new PriceFeed.OracleSetup[](0);

        // Deploy `PriceFeed.sol`
        priceFeed = new PriceFeed(computedPrismaCoreAddr, PRICE_FEED_ETH_FEED, oracleSetups);
        console.log("PriceFeed computed at: ", computedPriceFeedAddr);
        console.log("PriceFeed deployed at: ", address(priceFeed));
        assert(computedPriceFeedAddr == address(priceFeed));

        // Deploy `PrismaCore.sol`
        prismaCore =
            new PrismaCore(PRISMA_CORE_OWNER, PRISMA_CORE_GUARDIAN, computedPriceFeedAddr, PRISMA_CORE_FEE_RECEIVER);
        console.log("PrismaCore computed at: ", computedPrismaCoreAddr);
        console.log("PrismaCore deployed at: ", address(prismaCore));
        assert(computedPrismaCoreAddr == address(prismaCore));

        // Deploy `GasPool.sol`
        gasPool = new GasPool();
        console.log("GasPool computed at: ", computedGasPoolAddr);
        console.log("GasPool deployed at: ", address(gasPool));
        assert(computedGasPoolAddr == address(gasPool));

        // Deploy `BorrowerOperations.sol`
        borrowerOperations = new BorrowerOperations(
            computedPrismaCoreAddr, computedDebtTokenAddr, computedFactoryAddr, BO_MIN_NET_DEBT, GAS_COMPENSATION
        );
        console.log("BorrowerOperations computed at: ", computedBorrowerOperationsAddr);
        console.log("BorrowerOperations deployed at: ", address(borrowerOperations));
        assert(computedBorrowerOperationsAddr == address(borrowerOperations));

        // Deploy `DebtToken.sol`
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            computedStabilityPoolAddr,
            computedBorrowerOperationsAddr,
            IPrismaCore(computedPrismaCoreAddr),
            DEBT_TOKEN_LAYER_ZERO_END_POINT,
            computedFactoryAddr,
            computedGasPoolAddr,
            GAS_COMPENSATION
        );
        console.log("DebtToken computed at: ", computedDebtTokenAddr);
        console.log("DebtToken deployed at: ", address(debtToken));
        assert(computedDebtTokenAddr == address(debtToken));

        // Deploy `LiquidationManager.sol`
        liquidationManager = new LiquidationManager(
            IStabilityPool(computedStabilityPoolAddr),
            IBorrowerOperations(computedBorrowerOperationsAddr),
            computedFactoryAddr,
            GAS_COMPENSATION
        );
        console.log("LiquidationManager computed at: ", computedLiquidationManagerAddr);
        console.log("LiquidationManager deployed at: ", address(liquidationManager));
        assert(computedLiquidationManagerAddr == address(liquidationManager));

        // Deploy `StabilityPool.sol`
        stabilityPool = new StabilityPool(
            computedPrismaCoreAddr,
            IDebtToken(computedDebtTokenAddr),
            computedFactoryAddr,
            computedLiquidationManagerAddr
        );
        console.log("StabilityPool computed at: ", computedStabilityPoolAddr);
        console.log("StabilityPool deployed at: ", address(stabilityPool));
        assert(computedStabilityPoolAddr == address(stabilityPool));

        // Deploy `TroveManager.sol`
        troveManager = new TroveManager(
            computedPrismaCoreAddr,
            computedGasPoolAddr,
            computedDebtTokenAddr,
            computedBorrowerOperationsAddr,
            computedLiquidationManagerAddr,
            GAS_COMPENSATION
        );
        console.log("TroveManager computed at: ", computedTroveManagerAddr);
        console.log("TroveManager deployed at: ", address(troveManager));
        assert(computedTroveManagerAddr == address(troveManager));

        // Deploy `Factory.sol`
        factory = new Factory(
            computedPrismaCoreAddr,
            IDebtToken(computedDebtTokenAddr),
            IStabilityPool(computedStabilityPoolAddr),
            IBorrowerOperations(computedBorrowerOperationsAddr),
            computedSortedTrovesAddr,
            computedTroveManagerAddr,
            ILiquidationManager(computedLiquidationManagerAddr)
        );
        console.log("Factory computed at: ", computedFactoryAddr);
        console.log("Factory deployed at: ", address(factory));
        assert(computedFactoryAddr == address(factory));

        vm.stopBroadcast();
    }
}
