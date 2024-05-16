// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../src/interfaces/core/IOSHIToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IMultiTroveGetter} from "../src/helpers/interfaces/IMultiTroveGetter.sol";
import {ISatoshiBORouter} from "../src/helpers/interfaces/ISatoshiBORouter.sol";
import {ISatoshiLPFactory} from "../src/interfaces/core/ISatoshiLPFactory.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";
import {CommunityIssuance} from "../src/OSHI/CommunityIssuance.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {SatoshiLPFactory} from "../src/SLP/SatoshiLPFactory.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {MultiTroveGetter} from "../src/helpers/MultiTroveGetter.sol";
import {SatoshiBORouter} from "../src/helpers/SatoshiBORouter.sol";
import {
    SATOSHI_CORE_OWNER,
    SATOSHI_CORE_GUARDIAN,
    SATOSHI_CORE_FEE_RECEIVER,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    BO_MIN_NET_DEBT,
    GAS_COMPENSATION,
    WETH_ADDRESS,
    PYTH_ADDRESS,
    SP_CLAIM_START_TIME,
    SP_ALLOCATION
} from "./DeploySetupConfig.sol";

contract DeploySetupScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public deployer;
    address public satoshiCoreOwner;
    uint64 public nonce;

    /* non-upgradeable contracts */
    IGasPool gasPool;
    ISatoshiCore satoshiCore;
    /* implementation contracts addresses */
    ISortedTroves sortedTrovesImpl;
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ITroveManager troveManagerImpl;
    IRewardManager rewardManagerImpl;
    IDebtToken debtTokenImpl;
    IFactory factoryImpl;
    ICommunityIssuance communityIssuanceImpl;
    IOSHIToken oshiTokenImpl;
    ISatoshiLPFactory satoshiLPFactoryImpl;
    /* UUPS proxy contracts */
    IPriceFeedAggregator priceFeedAggregatorProxy;
    IBorrowerOperations borrowerOperationsProxy;
    ILiquidationManager liquidationManagerProxy;
    IStabilityPool stabilityPoolProxy;
    IRewardManager rewardManagerProxy;
    IDebtToken debtTokenProxy;
    IFactory factoryProxy;
    ICommunityIssuance communityIssuanceProxy;
    IOSHIToken oshiTokenProxy;
    ISatoshiLPFactory satoshiLPFactoryProxy;
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
    address cpRewardManagerImplAddr;
    address cpDebtTokenImplAddr;
    address cpFactoryImplAddr;
    address cpCommunityIssuanceImplAddr;
    address cpOshiTokenImplAddr;
    address cpSatoshiLPFactoryImplAddr;
    // non-upgradeable contracts
    address cpGasPoolAddr;
    address cpSatoshiCoreAddr;
    // UUPS proxy contracts
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    address cpRewardManagerProxyAddr;
    address cpDebtTokenProxyAddr;
    address cpFactoryProxyAddr;
    address cpCommunityIssuanceProxyAddr;
    address cpOshiTokenProxyAddr;
    address cpSatoshiLPFactoryProxyAddr;
    // Beacon contracts
    address cpSortedTrovesBeaconAddr;
    address cpTroveManagerBeaconAddr;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);
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
        cpRewardManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpOshiTokenImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiLPFactoryImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        // upgradeable contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSortedTrovesBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpRewardManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpOshiTokenProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiLPFactoryProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        // Deploy implementation contracts
        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        sortedTrovesImpl = new SortedTroves();
        troveManagerImpl = new TroveManager();
        rewardManagerImpl = new RewardManager();
        debtTokenImpl = new DebtToken();
        factoryImpl = new Factory();
        communityIssuanceImpl = new CommunityIssuance();
        oshiTokenImpl = new OSHIToken();
        satoshiLPFactoryImpl = new SatoshiLPFactory();

        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // SatoshiCore
        satoshiCore = new SatoshiCore(
            SATOSHI_CORE_OWNER, SATOSHI_CORE_GUARDIAN, SATOSHI_CORE_FEE_RECEIVER, cpRewardManagerProxyAddr
        );
        assert(cpSatoshiCoreAddr == address(satoshiCore));

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
                IDebtToken(cpDebtTokenProxyAddr),
                IFactory(cpFactoryProxyAddr),
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
                IFactory(cpFactoryProxyAddr),
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
                IDebtToken(cpDebtTokenProxyAddr),
                IFactory(cpFactoryProxyAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                ICommunityIssuance(cpCommunityIssuanceProxyAddr)
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

        // rewardManager
        data = abi.encodeCall(IRewardManager.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        proxy = address(new ERC1967Proxy(address(rewardManagerImpl), data));
        rewardManagerProxy = IRewardManager(proxy);
        assert(proxy == cpRewardManagerProxyAddr);

        // debtToken
        data = abi.encodeCall(
            IDebtToken.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                DEBT_TOKEN_NAME,
                DEBT_TOKEN_SYMBOL,
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryProxyAddr),
                IGasPool(cpGasPoolAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(debtTokenImpl), data));
        debtTokenProxy = IDebtToken(proxy);
        assert(proxy == cpDebtTokenProxyAddr);

        // factory
        data = abi.encodeCall(
            IFactory.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenProxyAddr),
                IGasPool(cpGasPoolAddr),
                IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBeacon(cpSortedTrovesBeaconAddr),
                IBeacon(cpTroveManagerBeaconAddr),
                ICommunityIssuance(cpCommunityIssuanceProxyAddr),
                IRewardManager(cpRewardManagerProxyAddr),
                GAS_COMPENSATION
            )
        );
        proxy = address(new ERC1967Proxy(address(factoryImpl), data));
        factoryProxy = IFactory(proxy);
        assert(proxy == cpFactoryProxyAddr);

        // communityIssuance
        data = abi.encodeCall(
            ICommunityIssuance.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IOSHIToken(cpOshiTokenProxyAddr),
                IStabilityPool(cpStabilityPoolProxyAddr)
            )
        );
        proxy = address(new ERC1967Proxy(address(communityIssuanceImpl), data));
        communityIssuanceProxy = ICommunityIssuance(proxy);
        assert(proxy == cpCommunityIssuanceProxyAddr);

        // oshiToken
        data = abi.encodeCall(IOSHIToken.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        proxy = address(new ERC1967Proxy(address(oshiTokenImpl), data));
        oshiTokenProxy = IOSHIToken(proxy);
        assert(proxy == cpOshiTokenProxyAddr);

        // LP Factory
        data = abi.encodeCall(
            ISatoshiLPFactory.initialize,
            (ISatoshiCore(cpSatoshiCoreAddr), ICommunityIssuance(cpCommunityIssuanceProxyAddr))
        );
        proxy = address(new ERC1967Proxy(address(satoshiLPFactoryImpl), data));
        satoshiLPFactoryProxy = ISatoshiLPFactory(proxy);
        assert(proxy == cpSatoshiLPFactoryProxyAddr);

        // MultiCollateralHintHelpers
        hintHelpers = new MultiCollateralHintHelpers(borrowerOperationsProxy, GAS_COMPENSATION);

        // MultiTroveGetter
        multiTroveGetter = new MultiTroveGetter();

        // SatoshiBORouter
        nonce = vm.getNonce(deployer);
        address cpSatoshiBORouterAddr = vm.computeCreateAddress(deployer, nonce);
        satoshiBORouter =
            new SatoshiBORouter(debtTokenProxy, borrowerOperationsProxy, IWETH(WETH_ADDRESS), IPyth(PYTH_ADDRESS));
        assert(cpSatoshiBORouterAddr == address(satoshiBORouter));

        vm.stopBroadcast();

        // Set configuration by owner
        _setConfigByOwner(OWNER_PRIVATE_KEY);

        console.log("Deployed contracts:");
        console.log("priceFeedAggregatorImpl:", address(priceFeedAggregatorImpl));
        console.log("borrowerOperationsImpl:", address(borrowerOperationsImpl));
        console.log("liquidationManagerImpl:", address(liquidationManagerImpl));
        console.log("stabilityPoolImpl:", address(stabilityPoolImpl));
        console.log("sortedTrovesImpl:", address(sortedTrovesImpl));
        console.log("troveManagerImpl:", address(troveManagerImpl));
        console.log("rewardManagerImpl:", address(rewardManagerImpl));
        console.log("debtTokenImpl:", address(debtTokenImpl));
        console.log("factoryImpl:", address(factoryImpl));
        console.log("communityIssuanceImpl:", address(communityIssuanceImpl));
        console.log("oshiTokenImpl:", address(oshiTokenImpl));
        console.log("satoshiLPFactoryImpl:", address(satoshiLPFactoryImpl));
        console.log("gasPool:", address(gasPool));
        console.log("satoshiCore:", address(satoshiCore));
        console.log("priceFeedAggregatorProxy:", address(priceFeedAggregatorProxy));
        console.log("borrowerOperationsProxy:", address(borrowerOperationsProxy));
        console.log("liquidationManagerProxy:", address(liquidationManagerProxy));
        console.log("stabilityPoolProxy:", address(stabilityPoolProxy));
        console.log("sortedTrovesBeacon:", address(sortedTrovesBeacon));
        console.log("troveManagerBeacon:", address(troveManagerBeacon));
        console.log("rewardManagerProxy:", address(rewardManagerProxy));
        console.log("debtTokenProxy:", address(debtTokenProxy));
        console.log("factoryProxy:", address(factoryProxy));
        console.log("communityIssuanceProxy:", address(communityIssuanceProxy));
        console.log("oshiTokenProxy:", address(oshiTokenProxy));
        console.log("satoshiLPFactoryProxy:", address(satoshiLPFactoryProxy));
        console.log("hintHelpers:", address(hintHelpers));
        console.log("multiTroveGetter:", address(multiTroveGetter));
        console.log("satoshiBORouter:", address(satoshiBORouter));
    }

    function _setConfigByOwner(uint256 owner_private_key) internal {
        _setRewardManager(owner_private_key, address(rewardManagerProxy));
        _setSPCommunityIssuanceAllocation(owner_private_key);
        _setAddress(owner_private_key, borrowerOperationsProxy, IWETH(WETH_ADDRESS), debtTokenProxy, oshiTokenProxy);
        _setClaimStartTime(owner_private_key, SP_CLAIM_START_TIME);
    }

    function _setRewardManager(uint256 owner_private_key, address _rewardManager) internal {
        vm.startBroadcast(owner_private_key);
        satoshiCore.setRewardManager(_rewardManager);
        assert(satoshiCore.rewardManager() == _rewardManager);
        vm.stopBroadcast();
    }

    function _setSPCommunityIssuanceAllocation(uint256 owner_private_key) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = cpStabilityPoolProxyAddr;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = SP_ALLOCATION;
        vm.startBroadcast(owner_private_key);
        communityIssuanceProxy.setAllocated(_recipients, _amounts);
        vm.stopBroadcast();
    }

    function _setAddress(
        uint256 owner_private_key,
        IBorrowerOperations _borrowerOperations,
        IWETH _weth,
        IDebtToken _debtToken,
        IOSHIToken _oshiToken
    ) internal {
        vm.startBroadcast(owner_private_key);
        rewardManagerProxy.setAddresses(_borrowerOperations, _weth, _debtToken, _oshiToken);
        vm.stopBroadcast();
    }

    function _setClaimStartTime(uint256 owner_private_key, uint32 _claimStartTime) internal {
        vm.startBroadcast(owner_private_key);
        stabilityPoolProxy.setClaimStartTime(_claimStartTime);
        vm.stopBroadcast();
    }
}
