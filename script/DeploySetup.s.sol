// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IMultiTroveGetter} from "../src/helpers/interfaces/IMultiTroveGetter.sol";
import {ISatoshiBORouter} from "../src/helpers/interfaces/ISatoshiBORouter.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";
import {CommunityIssuance} from "../src/OSHI/CommunityIssuance.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {MultiTroveGetter} from "../src/helpers/MultiTroveGetter.sol";
import {SatoshiBORouter} from "../src/helpers/SatoshiBORouter.sol";
import {
    SATOSHI_CORE_OWNER,
    SATOSHI_CORE_GUARDIAN,
    SATOSHI_CORE_FEE_RECEIVER,
    SATOSHI_CORE_REWARD_MANAGER,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    BO_MIN_NET_DEBT,
    GAS_COMPENSATION,
    WETH_ADDRESS
} from "./DeploySetupConfig.sol";

contract DeploySetupScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address public deployer;
    uint64 public nonce;

    /* non-upgradeable contracts */
    IGasPool gasPool;
    ISatoshiCore satoshiCore;
    IDebtToken debtToken;
    IFactory factory;
    ICommunityIssuance communityIssuance;
    /* implementation contracts addresses */
    ISortedTroves sortedTrovesImpl;
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ITroveManager troveManagerImpl;
    /* UUPS proxy contracts */
    IPriceFeedAggregator priceFeedAggregatorProxy;
    IBorrowerOperations borrowerOperationsProxy;
    ILiquidationManager liquidationManagerProxy;
    IStabilityPool stabilityPoolProxy;
    /* Beacon contract */
    UpgradeableBeacon sortedTrovesBeacon;
    UpgradeableBeacon troveManagerBeacon;
    /* Helpers contracts */
    IMultiCollateralHintHelpers hintHelpers;
    IMultiTroveGetter multiTroveGetter;
    ISatoshiBORouter satoshiBORouter;

    /* computed contracts for deployment */
    // implementation contracts
    address cpPriceFeedAggregatorImplAddr;
    address cpBorrowerOperationsImplAddr;
    address cpLiquidationManagerImplAddr;
    address cpStabilityPoolImplAddr;
    address cpSortedTrovesImplAddr;
    address cpTroveManagerImplAddr;
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpSatoshiCoreAddr;
    address cpDebtTokenAddr;
    address cpFactoryAddr;
    address cpCommunityIssuanceAddr;
    // UUPS proxy contracts
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    // Beacon contracts
    address cpSortedTrovesBeaconAddr;
    address cpTroveManagerBeaconAddr;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        // Get nonce for computing contracts address
        nonce = vm.getNonce(deployer);

        // computed contracts address for deployment
        // implementation contracts
        cpPriceFeedAggregatorImplAddr = vm.computeCreateAddress(deployer, nonce);
        cpBorrowerOperationsImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSortedTrovesImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceAddr = vm.computeCreateAddress(deployer, ++nonce);
        // upgradeable contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSortedTrovesBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);

        // Deploy implementation contracts
        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        sortedTrovesImpl = new SortedTroves();
        troveManagerImpl = new TroveManager();

        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // SatoshiCore
        satoshiCore = new SatoshiCore(
            SATOSHI_CORE_OWNER, SATOSHI_CORE_GUARDIAN, SATOSHI_CORE_FEE_RECEIVER, SATOSHI_CORE_REWARD_MANAGER
        );
        assert(cpSatoshiCoreAddr == address(satoshiCore));

        // DebtToken
        debtToken = new DebtToken(
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ISatoshiCore(cpSatoshiCoreAddr),
            IFactory(cpFactoryAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );
        assert(cpDebtTokenAddr == address(debtToken));

        // Factory
        factory = new Factory(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IGasPool(cpGasPoolAddr),
            IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBeacon(cpSortedTrovesBeaconAddr),
            IBeacon(cpTroveManagerBeaconAddr),
            ICommunityIssuance(cpCommunityIssuanceAddr),
            GAS_COMPENSATION
        );
        assert(cpFactoryAddr == address(factory));

        // Community Issuance
        communityIssuance = new CommunityIssuance(ISatoshiCore(cpSatoshiCoreAddr));
        assert(cpCommunityIssuanceAddr == address(communityIssuance));

        // Deploy proxy contracts
        bytes memory data;
        address proxy;

        // PriceFeedAggregator
        data = abi.encodeCall(IPriceFeedAggregator.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        proxy = address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data));
        priceFeedAggregatorProxy = IPriceFeedAggregator(proxy);
        assert(proxy == cpPriceFeedAggregatorProxyAddr);

        // BorrowerOperations
        data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(borrowerOperationsImpl), data));
        borrowerOperationsProxy = IBorrowerOperations(proxy);
        assert(proxy == cpBorrowerOperationsProxyAddr);

        // LiquidationManager
        data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(liquidationManagerImpl), data));
        liquidationManagerProxy = ILiquidationManager(proxy);
        assert(proxy == cpLiquidationManagerProxyAddr);

        // StabilityPool
        data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                ICommunityIssuance(cpCommunityIssuanceAddr)
            )
        );
        proxy = address(new ERC1967Proxy(address(stabilityPoolImpl), data));
        stabilityPoolProxy = IStabilityPool(proxy);
        assert(proxy == cpStabilityPoolProxyAddr);

        // SortedTrovesBeacon
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl));
        assert(cpSortedTrovesBeaconAddr == address(sortedTrovesBeacon));

        // TroveManagerBeacon
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl));
        assert(cpTroveManagerBeaconAddr == address(troveManagerBeacon));

        // MultiCollateralHintHelpers
        hintHelpers = new MultiCollateralHintHelpers(borrowerOperationsProxy, GAS_COMPENSATION);

        // MultiTroveGetter
        multiTroveGetter = new MultiTroveGetter();

        // SatoshiBORouter
        satoshiBORouter = new SatoshiBORouter(debtToken, borrowerOperationsProxy, IWETH(WETH_ADDRESS));

        console.log("Deployed contracts:");
        console.log("priceFeedAggregatorImpl:", address(priceFeedAggregatorImpl));
        console.log("borrowerOperationsImpl:", address(borrowerOperationsImpl));
        console.log("liquidationManagerImpl:", address(liquidationManagerImpl));
        console.log("stabilityPoolImpl:", address(stabilityPoolImpl));
        console.log("sortedTrovesImpl:", address(sortedTrovesImpl));
        console.log("troveManagerImpl:", address(troveManagerImpl));
        console.log("gasPool:", address(gasPool));
        console.log("satoshiCore:", address(satoshiCore));
        console.log("debtToken:", address(debtToken));
        console.log("factory:", address(factory));
        console.log("communityIssuance:", address(communityIssuance));
        console.log("priceFeedAggregatorProxy:", address(priceFeedAggregatorProxy));
        console.log("borrowerOperationsProxy:", address(borrowerOperationsProxy));
        console.log("liquidationManagerProxy:", address(liquidationManagerProxy));
        console.log("stabilityPoolProxy:", address(stabilityPoolProxy));
        console.log("sortedTrovesBeacon:", address(sortedTrovesBeacon));
        console.log("troveManagerBeacon:", address(troveManagerBeacon));
        console.log("hintHelpers:", address(hintHelpers));
        console.log("multiTroveGetter:", address(multiTroveGetter));
        console.log("satoshiBORouter:", address(satoshiBORouter));

        vm.stopBroadcast();
    }
}
