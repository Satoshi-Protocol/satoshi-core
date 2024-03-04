// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
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
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    GAS_COMPENSATION,
    BO_MIN_NET_DEBT
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
        assert(satoshiCore.startTime() == (block.timestamp / 1 weeks) * 1 weeks);

        // DebtToken
        _deployDebtToken(DEPLOYER);
        assert(cpDebtTokenAddr == address(debtToken));
        assert(debtToken.stabilityPool() == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(debtToken.borrowerOperations() == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(debtToken.factory() == IFactory(cpFactoryAddr));
        assert(debtToken.gasPool() == IGasPool(cpGasPoolAddr));
        assert(debtToken.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // Factory
        _deployFactory(DEPLOYER);
        assert(cpFactoryAddr == address(factory));
        assert(factory.owner() == OWNER);
        assert(factory.guardian() == GUARDIAN);
        assert(factory.debtToken() == IDebtToken(cpDebtTokenAddr));
        assert(factory.stabilityPoolProxy() == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(factory.borrowerOperationsProxy() == IBorrowerOperations(cpBorrowerOperationsProxyAddr));
        assert(factory.liquidationManagerProxy() == ILiquidationManager(cpLiquidationManagerProxyAddr));
        assert(factory.sortedTrovesBeacon() == IBeacon(cpSortedTrovesBeaconAddr));
        assert(factory.troveManagerBeacon() == IBeacon(cpTroveManagerBeaconAddr));
        assert(factory.communityIssuance() == ICommunityIssuance(cpCommunityIssuanceAddr));

        // Community Issuance
        _deployCommunityIssuance(DEPLOYER);
        assert(cpCommunityIssuanceAddr == address(communityIssuance));
        assert(communityIssuance.owner() == OWNER);

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
        assert(borrowerOperationsProxy.debtToken() == IDebtToken(cpDebtTokenAddr));
        assert(borrowerOperationsProxy.factory() == IFactory(cpFactoryAddr));
        assert(borrowerOperationsProxy.minNetDebt() == BO_MIN_NET_DEBT);
        assert(borrowerOperationsProxy.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        borrowerOperationsProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IFactory(cpFactoryAddr),
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
        assert(liquidationManagerProxy.factory() == IFactory(cpFactoryAddr));
        assert(liquidationManagerProxy.DEBT_GAS_COMPENSATION() == GAS_COMPENSATION);

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        liquidationManagerProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IStabilityPool(cpStabilityPoolProxyAddr),
            IBorrowerOperations(cpBorrowerOperationsProxyAddr),
            IFactory(cpFactoryAddr),
            GAS_COMPENSATION
        );

        // StabilityPool
        _deployStabilityPoolProxy(DEPLOYER);
        assert(stabilityPoolProxy == IStabilityPool(cpStabilityPoolProxyAddr));
        assert(stabilityPoolProxy.owner() == OWNER);
        assert(stabilityPoolProxy.guardian() == GUARDIAN);
        assert(stabilityPoolProxy.debtToken() == IDebtToken(cpDebtTokenAddr));
        assert(stabilityPoolProxy.factory() == IFactory(cpFactoryAddr));
        assert(stabilityPoolProxy.liquidationManager() == ILiquidationManager(cpLiquidationManagerProxyAddr));
        assert(stabilityPoolProxy.communityIssuance() == ICommunityIssuance(cpCommunityIssuanceAddr));

        // test re-initialize fail
        vm.expectRevert("Initializable: contract is already initialized");
        stabilityPoolProxy.initialize(
            ISatoshiCore(cpSatoshiCoreAddr),
            IDebtToken(cpDebtTokenAddr),
            IFactory(cpFactoryAddr),
            ILiquidationManager(cpLiquidationManagerProxyAddr),
            ICommunityIssuance(cpCommunityIssuanceAddr)
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
