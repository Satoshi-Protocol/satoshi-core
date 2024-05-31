// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../src/interfaces/core/IOSHIToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {Factory} from "../src/core/Factory.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    FEE_RECEIVER,
    REWARD_MANAGER,
    VAULT,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    GAS_COMPENSATION,
    BO_MIN_NET_DEBT,
    SP_CLAIM_START_TIME
} from "./TestConfig.sol";

contract DeploySetupTest is Test, DeployBase {
    function setUp() public override {
        super.setUp();

        // compute all contracts address
        _computeContractsAddress(DEPLOYER);

        // deploy all implementation contracts
        _deployImplementationContracts(DEPLOYER);
    }

    function testDeploySetup() public {
        /* Deploy non-upgradeable contracts */

        // GasPool
        _deployGasPool(DEPLOYER);
        assert(cpGasPoolAddr == address(gasPool));

        // SatoshiCore
        _deploySatoshiCore(DEPLOYER);
        assert(cpSatoshiCoreAddr == address(satoshiCore));
        assert(satoshiCore.owner() == OWNER);
        assert(satoshiCore.guardian() == GUARDIAN);
        assert(satoshiCore.feeReceiver() == FEE_RECEIVER);
        assert(satoshiCore.rewardManager() == REWARD_MANAGER);
        assert(satoshiCore.startTime() == block.timestamp);

        /* Deploy UUPS proxy contracts */

        // PriceFeedAggregator
        _deployPriceFeedAggregatorProxy(DEPLOYER);
        assert(priceFeedAggregatorProxy == IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr));
        assert(priceFeedAggregatorProxy.owner() == OWNER);
        assert(priceFeedAggregatorProxy.guardian() == GUARDIAN);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        priceFeedAggregatorProxy.initialize(ISatoshiCore(cpSatoshiCoreAddr));

        // BorrowerOperations
        _deployBorrowerOperationsProxy(DEPLOYER);
        assert(borrowerOperationsProxy == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(borrowerOperationsProxy.owner() == OWNER);
        assert(borrowerOperationsProxy.guardian() == GUARDIAN);
        assert(borrowerOperationsProxy.debtToken() == IDebtToken(cpDebtTokenProxyAddr));
        assert(borrowerOperationsProxy.factory() == IFactory(cpFactoryProxyAddr));
        assert(borrowerOperationsProxy.minNetDebt() == BO_MIN_NET_DEBT);
        assert(borrowerOperationsProxy.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        borrowerOperationsProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenProxyAddr),
            IFactory(cpFactoryProxyAddr),
            BO_MIN_NET_DEBT,
            GAS_COMPENSATION
        );

        // LiquidationManager
        _deployLiquidationManagerProxy(DEPLOYER);
        assert(liquidationManagerProxy == ILiquidationManager(cpLiquidationManagerProxyAddr));
        assert(liquidationManagerProxy.owner() == OWNER);
        assert(liquidationManagerProxy.guardian() == GUARDIAN);
        assert(liquidationManagerProxy.stabilityPool() == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(liquidationManagerProxy.borrowerOperations() == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(liquidationManagerProxy.factory() == IFactory(cpFactoryProxyAddr));
        assert(liquidationManagerProxy.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        liquidationManagerProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            IFactory(cpFactoryProxyAddr),
            GAS_COMPENSATION
        );

        // StabilityPool
        _deployStabilityPoolProxy(DEPLOYER);
        assert(stabilityPoolProxy == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(stabilityPoolProxy.owner() == OWNER);
        assert(stabilityPoolProxy.guardian() == GUARDIAN);
        assert(stabilityPoolProxy.debtToken() == IDebtToken(cpDebtTokenProxyAddr));
        assert(stabilityPoolProxy.factory() == IFactory(cpFactoryProxyAddr));
        assert(stabilityPoolProxy.liquidationManager() == ILiquidationManager(cpLiquidationManagerProxyAddr));
        assert(stabilityPoolProxy.communityIssuance() == ICommunityIssuance(cpCommunityIssuanceProxyAddr));

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        stabilityPoolProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenProxyAddr),
            IFactory(cpFactoryProxyAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr),
            ICommunityIssuance(cpCommunityIssuanceProxyAddr)
        );

        // Reward Manager
        _deployRewardManagerProxy(DEPLOYER);
        assert(rewardManagerProxy == IRewardManager(cpRewardManagerProxyAddr));
        assert(rewardManagerProxy.owner() == OWNER);
        assert(rewardManagerProxy.guardian() == GUARDIAN);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        rewardManagerProxy.initialize(ISatoshiCore(cpSatoshiCoreAddr));

        // DebtToken
        _deployDebtTokenProxy(DEPLOYER);
        assert(cpDebtTokenProxyAddr == address(debtTokenProxy));
        assert(debtTokenProxy.stabilityPool() == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(debtTokenProxy.borrowerOperations() == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(debtTokenProxy.factory() == IFactory(cpFactoryProxyAddr));
        assert(debtTokenProxy.gasPool() == IGasPool(cpGasPoolAddr));
        assert(debtTokenProxy.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        debtTokenProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            DEBT_TOKEN_NAME,
            DEBT_TOKEN_SYMBOL,
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            IFactory(cpFactoryProxyAddr),
            IGasPool(cpGasPoolAddr),
            GAS_COMPENSATION
        );

        // Factory
        _deployFactoryProxy(DEPLOYER);
        assert(cpFactoryProxyAddr == address(factoryProxy));
        assert(factoryProxy.owner() == OWNER);
        assert(factoryProxy.guardian() == GUARDIAN);
        assert(factoryProxy.debtToken() == IDebtToken(cpDebtTokenProxyAddr));
        assert(factoryProxy.stabilityPoolProxy() == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(factoryProxy.borrowerOperationsProxy() == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(factoryProxy.liquidationManagerProxy() == ILiquidationManager(cpLiquidationManagerProxyAddr));
        assert(factoryProxy.sortedTrovesBeacon() == IBeacon(cpSortedTrovesBeaconAddr));
        assert(factoryProxy.troveManagerBeacon() == IBeacon(cpTroveManagerBeaconAddr));
        assert(factoryProxy.communityIssuance() == ICommunityIssuance(cpCommunityIssuanceProxyAddr));

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        factoryProxy.initialize(
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
            GAS_COMPENSATION
        );

        // Community Issuance
        _deployCommunityIssuanceProxy(DEPLOYER);
        assert(cpCommunityIssuanceProxyAddr == address(communityIssuanceProxy));
        assert(communityIssuanceProxy.owner() == OWNER);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        communityIssuanceProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr), IOSHIToken(cpOshiTokenProxyAddr), IStabilityPool(cpStabilityPoolProxyAddr)
        );

        _deployOSHITokenProxy(DEPLOYER);
        assert(cpOshiTokenProxyAddr == address(oshiTokenProxy));

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        oshiTokenProxy.initialize(ISatoshiCore(cpSatoshiCoreAddr));

        _deploySatoshiLPFactoryProxy(DEPLOYER);
        assert(cpSatoshiLPFactoryProxyAddr == address(satoshiLPFactoryProxy));
        assert(satoshiLPFactoryProxy.owner() == OWNER);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        satoshiLPFactoryProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr), ICommunityIssuance(cpCommunityIssuanceProxyAddr)
        );

        /* Deploy Beacon contracts */

        // SortedTrovesBeacon
        _deploySortedTrovesBeacon(DEPLOYER);
        assert(sortedTrovesBeacon.implementation() == address(sortedTrovesImpl));

        // TroveManagerBeacon
        _deployTroveManagerBeacon(DEPLOYER);
        assert(troveManagerBeacon.implementation() == address(troveManagerImpl));
    }
}
