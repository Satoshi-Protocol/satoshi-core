// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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
    NATIVE_TOKEN_FEED,
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

    // implementation contracts addresses
    ISortedTroves sortedTrovesImpl;
    IPriceFeed priceFeedImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ITroveManager troveManagerImpl;

    // non-upgradeable contracts
    IGasPool gasPool;
    IPrismaCore prismaCore;
    IDebtToken debtToken;
    IFactory factory;

    /* computed contracts for deployment */
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpPrismaCoreAddr;
    address cpDebtTokenAddr;
    address cpFactoryAddr;
    // upgradeable contracts
    address cpSortedTrovesProxyAddr;
    address cpPriceFeedProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    address cpTroveManagerProxyAddr;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        // Deploy implementation contracts
        sortedTrovesImpl = new SortedTroves();
        priceFeedImpl = new PriceFeed();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        troveManagerImpl = new TroveManager();

        // Get nonce for computing contracts address
        nonce = vm.getNonce(deployer);

        // computed contracts address for deployment
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, nonce);
        cpPrismaCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        // upgradeable contracts
        cpSortedTrovesProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpPriceFeedProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);

        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // PrismaCore
        prismaCore = new PrismaCore(
            PRISMA_CORE_OWNER, PRISMA_CORE_GUARDIAN, IPriceFeed(cpPriceFeedProxyAddr), PRISMA_CORE_FEE_RECEIVER
        );
        assert(cpPrismaCoreAddr == address(prismaCore));

        // DebtToken
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            IPrismaCore(cpPrismaCoreAddr),
            DEBT_TOKEN_LAYER_ZERO_END_POINT,
            IFactory(cpFactoryAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );
        assert(cpDebtTokenAddr == address(debtToken));

        // Factory
        factory = new Factory(
            IPrismaCore(cpPrismaCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ISortedTroves(cpSortedTrovesProxyAddr),
            ITroveManager(cpTroveManagerProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr)
        );
        assert(cpFactoryAddr == address(factory));

        // Deploy proxy contracts
        bytes memory data;
        address proxy;

        // SortedTroves
        data = abi.encodeCall(ISortedTroves.initialize, (IPrismaCore(cpPrismaCoreAddr)));
        proxy = address(new ERC1967Proxy(address(sortedTrovesImpl), data));
        assert(proxy == cpSortedTrovesProxyAddr);

        // PriceFeed
        OracleSetup[] memory oracleSetups = new OracleSetup[](0); // empty array
        data = abi.encodeCall(
            IPriceFeed.initialize,
            (IPrismaCore(cpPrismaCoreAddr), IAggregatorV3Interface(NATIVE_TOKEN_FEED), oracleSetups)
        );
        proxy = address(new ERC1967Proxy(address(priceFeedImpl), data));
        assert(proxy == cpPriceFeedProxyAddr);

        // BorrowerOperations
        data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(borrowerOperationsImpl), data));
        assert(proxy == cpBorrowerOperationsProxyAddr);

        // LiquidationManager
        data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(liquidationManagerImpl), data));
        assert(proxy == cpLiquidationManagerProxyAddr);

        // StabilityPool
        data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr)
            )
        );
        proxy = address(new ERC1967Proxy(address(stabilityPoolImpl), data));
        assert(proxy == cpStabilityPoolProxyAddr);

        // TroveManager
        data = abi.encodeCall(
            ITroveManager.initialize,
            (
                IPrismaCore(cpPrismaCoreAddr),
                IGasPool(cpGasPoolAddr),
                IDebtToken(cpDebtTokenAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(troveManagerImpl), data));
        assert(proxy == cpTroveManagerProxyAddr);

        vm.stopBroadcast();
    }
}
