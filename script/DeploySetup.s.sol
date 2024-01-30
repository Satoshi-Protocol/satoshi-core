// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IAggregatorV3Interface} from "../src/interfaces/IAggregatorV3Interface.sol";
import {IPrismaCore} from "../src/interfaces/IPrismaCore.sol";
import {IBorrowerOperations} from "../src/interfaces/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/IStabilityPool.sol";
import {IPriceFeed} from "../src/interfaces/IPriceFeed.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {IGasPool} from "../src/interfaces/IGasPool.sol";
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

        // Computed contract addresses
        address cpSortedTrovesAddr = vm.computeCreateAddress(deployer, nonce);
        address cpPriceFeedAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpPrismaCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpBorrowerOperationsAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpLiquidationManagerAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpStabilityPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpTroveManagerAddr = vm.computeCreateAddress(deployer, ++nonce);
        address cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);

        // Deploy `SortedTroves.sol`
        sortedTroves = new SortedTroves();
        assert(cpSortedTrovesAddr == address(sortedTroves));

        // Deploy `PriceFeed.sol`
        // empty array
        PriceFeed.OracleSetup[] memory oracleSetups = new PriceFeed.OracleSetup[](0);
        priceFeed =
            new PriceFeed(IPrismaCore(cpPrismaCoreAddr), IAggregatorV3Interface(PRICE_FEED_ETH_FEED), oracleSetups);
        assert(cpPriceFeedAddr == address(priceFeed));

        // Deploy `PrismaCore.sol`
        prismaCore = new PrismaCore(
            PRISMA_CORE_OWNER, PRISMA_CORE_GUARDIAN, IPriceFeed(cpPriceFeedAddr), PRISMA_CORE_FEE_RECEIVER
        );
        assert(cpPrismaCoreAddr == address(prismaCore));

        // Deploy `GasPool.sol`
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // Deploy `BorrowerOperations.sol`
        borrowerOperations = new BorrowerOperations(
            IPrismaCore(cpPrismaCoreAddr), cpDebtTokenAddr, cpFactoryAddr, BO_MIN_NET_DEBT, GAS_COMPENSATION
        );
        assert(cpBorrowerOperationsAddr == address(borrowerOperations));

        // Deploy `DebtToken.sol`
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolAddr),
            IBorrowerOperations(cpBorrowerOperationsAddr),
            IPrismaCore(cpPrismaCoreAddr),
            DEBT_TOKEN_LAYER_ZERO_END_POINT,
            IFactory(cpFactoryAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );
        assert(cpDebtTokenAddr == address(debtToken));

        // Deploy `LiquidationManager.sol`
        liquidationManager = new LiquidationManager(
            IStabilityPool(cpStabilityPoolAddr),
            IBorrowerOperations(cpBorrowerOperationsAddr),
            IFactory(cpFactoryAddr),
            GAS_COMPENSATION
        );
        assert(cpLiquidationManagerAddr == address(liquidationManager));

        // Deploy `StabilityPool.sol`
        stabilityPool = new StabilityPool(
            IPrismaCore(cpPrismaCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IFactory(cpFactoryAddr),
            ILiquidationManager(cpLiquidationManagerAddr)
        );
        assert(cpStabilityPoolAddr == address(stabilityPool));

        // Deploy `TroveManager.sol`
        troveManager = new TroveManager(
            IPrismaCore(cpPrismaCoreAddr),
            IGasPool(cpGasPoolAddr),
            IDebtToken(cpDebtTokenAddr),
            IBorrowerOperations(cpBorrowerOperationsAddr),
            ILiquidationManager(cpLiquidationManagerAddr),
            GAS_COMPENSATION
        );
        assert(cpTroveManagerAddr == address(troveManager));

        // Deploy `Factory.sol`
        factory = new Factory(
            IPrismaCore(cpPrismaCoreAddr),
            cpDebtTokenAddr,
            cpStabilityPoolAddr,
            cpBorrowerOperationsAddr,
            cpSortedTrovesAddr,
            cpTroveManagerAddr,
            cpLiquidationManagerAddr
        );
        assert(cpFactoryAddr == address(factory));

        vm.stopBroadcast();
    }
}
