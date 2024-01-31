// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IAggregatorV3Interface} from "../src/interfaces/IAggregatorV3Interface.sol";
import {IPrismaCore} from "../src/interfaces/IPrismaCore.sol";
import {IBorrowerOperations} from "../src/interfaces/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/IStabilityPool.sol";
import {IPriceFeed, OracleSetup} from "../src/interfaces/IPriceFeed.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {IGasPool} from "../src/interfaces/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/ITroveManager.sol";
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
} from "./DeploySetupConfig.sol";

contract DeploySetupScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;
    uint64 public nonce;

    // Deployed contracts
    ISortedTroves public sortedTroves;
    IPrismaCore public prismaCore;
    IPriceFeed public priceFeed;
    IGasPool public gasPool;
    IBorrowerOperations public borrowerOperations;
    IDebtToken public debtToken;
    ILiquidationManager public liquidationManager;
    IStabilityPool public stabilityPool;
    ITroveManager public troveManager;
    IFactory public factory;

    // Computed contract addresses
    ISortedTroves public cpSortedTroves;
    IPrismaCore public cpPrismaCore;
    IPriceFeed public cpPriceFeed;
    IGasPool public cpGasPool;
    IBorrowerOperations public cpBorrowerOperations;
    IDebtToken public cpDebtToken;
    ILiquidationManager public cpLiquidationManager;
    IStabilityPool public cpStabilityPool;
    ITroveManager public cpTroveManager;
    IFactory public cpFactory;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
        nonce = vm.getNonce(deployer);

        // Computed contract addresses
        cpSortedTroves = ISortedTroves(vm.computeCreateAddress(deployer, nonce));
        cpPriceFeed = IPriceFeed(vm.computeCreateAddress(deployer, ++nonce));
        cpPrismaCore = IPrismaCore(vm.computeCreateAddress(deployer, ++nonce));
        cpGasPool = IGasPool(vm.computeCreateAddress(deployer, ++nonce));
        cpBorrowerOperations = IBorrowerOperations(vm.computeCreateAddress(deployer, ++nonce));
        cpDebtToken = IDebtToken(vm.computeCreateAddress(deployer, ++nonce));
        cpLiquidationManager = ILiquidationManager(vm.computeCreateAddress(deployer, ++nonce));
        cpStabilityPool = IStabilityPool(vm.computeCreateAddress(deployer, ++nonce));
        cpTroveManager = ITroveManager(vm.computeCreateAddress(deployer, ++nonce));
        cpFactory = IFactory(vm.computeCreateAddress(deployer, ++nonce));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        console.log("start nonce");
        console.log(nonce);

        // Deploy `SortedTroves.sol`
        sortedTroves = new SortedTroves();
        assert(cpSortedTroves == sortedTroves);

        // Deploy `PriceFeed.sol`
        OracleSetup[] memory oracleSetups = new OracleSetup[](0); // empty array
        priceFeed = new PriceFeed(cpPrismaCore, IAggregatorV3Interface(PRICE_FEED_ETH_FEED), oracleSetups);
        assert(cpPriceFeed == priceFeed);

        // Deploy `PrismaCore.sol`
        prismaCore = new PrismaCore(PRISMA_CORE_OWNER, PRISMA_CORE_GUARDIAN, cpPriceFeed, PRISMA_CORE_FEE_RECEIVER);
        assert(cpPrismaCore == prismaCore);

        // Deploy `GasPool.sol`
        gasPool = new GasPool();
        assert(cpGasPool == gasPool);

        // Deploy `BorrowerOperations.sol`
        borrowerOperations =
            new BorrowerOperations(cpPrismaCore, cpDebtToken, cpFactory, BO_MIN_NET_DEBT, GAS_COMPENSATION);
        assert(cpBorrowerOperations == borrowerOperations);

        // Deploy `DebtToken.sol`
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            cpStabilityPool,
            cpBorrowerOperations,
            cpPrismaCore,
            DEBT_TOKEN_LAYER_ZERO_END_POINT,
            cpFactory,
            cpGasPool,
            GAS_COMPENSATION
        );
        assert(cpDebtToken == debtToken);

        // Deploy `LiquidationManager.sol`
        liquidationManager = new LiquidationManager(cpStabilityPool, cpBorrowerOperations, cpFactory, GAS_COMPENSATION);
        assert(cpLiquidationManager == liquidationManager);

        // Deploy `StabilityPool.sol`
        stabilityPool = new StabilityPool(cpPrismaCore, cpDebtToken, cpFactory, cpLiquidationManager);
        assert(cpStabilityPool == stabilityPool);

        // Deploy `TroveManager.sol`
        troveManager = new TroveManager(
            cpPrismaCore, cpGasPool, cpDebtToken, cpBorrowerOperations, cpLiquidationManager, GAS_COMPENSATION
        );
        assert(cpTroveManager == troveManager);

        // Deploy `Factory.sol`
        factory = new Factory(
            cpPrismaCore,
            cpDebtToken,
            cpStabilityPool,
            cpBorrowerOperations,
            cpSortedTroves,
            cpTroveManager,
            cpLiquidationManager
        );
        assert(cpFactory == factory);

        vm.stopBroadcast();
    }
}
