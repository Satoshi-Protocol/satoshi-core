// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {IPrismaCore} from "../src/interfaces/core/IPrismaCore.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IPriceFeedAggregator, OracleSetup} from "../src/interfaces/core/IPriceFeedAggregator.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IGasPool} from "../src/interfaces/core/IGasPool.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IPriceFeed} from "../src/interfaces/dependencies/IPriceFeed.sol";
import {SortedTroves} from "../src/core/SortedTroves.sol";
import {PrismaCore} from "../src/core/PrismaCore.sol";
import {PriceFeedAggregator} from "../src/core/PriceFeedAggregator.sol";
import {GasPool} from "../src/core/GasPool.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {Factory} from "../src/core/Factory.sol";

contract DeploySetupTest is Test {
    address internal DEPLOYER = 0x1234567890123456789012345678901234567890;
    address internal OWNER = 0x1111111111111111111111111111111111111111;
    address internal GUARDIAN = 0x2222222222222222222222222222222222222222;
    address internal FEE_RECEIVER = 0x3333333333333333333333333333333333333333;
    string internal DEBT_TOKEN_NAME = "TEST_TOKEN_NAME";
    string internal DEBT_TOKEN_SYMBOL = "TEST_TOKEN_SYMBOL";
    uint256 internal GAS_COMPENSATION = 5e18;

    // implementation contracts addresses
    ISortedTroves sortedTrovesImpl;
    IPriceFeedAggregator priceFeedAggregatorImpl;
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
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    address cpTroveManagerProxyAddr;

    function setUp() public {}

    function _deployImplementationContracts() internal {
        sortedTrovesImpl = new SortedTroves();
        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        troveManagerImpl = new TroveManager();
    }

    function _computeContractsAddress() internal {
        // Get nonce for computing contracts address
        uint64 nonce = vm.getNonce(DEPLOYER);

        // computed contracts address for deployment
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(DEPLOYER, nonce);
        cpPrismaCoreAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        // upgradeable contracts
        cpSortedTrovesProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        cpTroveManagerProxyAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
    }

    function testDeploySetup() public {
        _deployImplementationContracts();
        _computeContractsAddress();

        vm.startPrank(DEPLOYER);
        // Deploy non-upgradeable contracts
        // GasPool
        gasPool = new GasPool();
        assert(cpGasPoolAddr == address(gasPool));

        // PrismaCore
        prismaCore = new PrismaCore(OWNER, GUARDIAN, FEE_RECEIVER);
        assert(cpPrismaCoreAddr == address(prismaCore));
        assert(prismaCore.owner() == OWNER);
        assert(prismaCore.guardian() == GUARDIAN);
        assert(prismaCore.feeReceiver() == FEE_RECEIVER);
        assert(prismaCore.startTime() == (block.timestamp / 1 weeks) * 1 weeks);

        // // DebtToken
        // debtToken = new DebtToken(
        //     DEBT_TOKEN_NAME,
        //     DEBT_TOKEN_SYMBOL,
        //     IStabilityPool(cpStabilityPoolProxyAddr),
        //     IBorrowerOperations(cpBorrowerOperationsProxyAddr),
        //     IPrismaCore(cpPrismaCoreAddr),
        //     DEBT_TOKEN_LAYER_ZERO_END_POINT,
        //     IFactory(cpFactoryAddr),
        //     IGasPool(cpGasPoolAddr),
        //     GAS_COMPENSATION
        // );
        // assert(cpDebtTokenAddr == address(debtToken));

        // // Factory
        // factory = new Factory(
        //     IPrismaCore(cpPrismaCoreAddr),
        //     IDebtToken(cpDebtTokenAddr),
        //     IStabilityPool(cpStabilityPoolProxyAddr),
        //     IBorrowerOperations(cpBorrowerOperationsProxyAddr),
        //     ISortedTroves(cpSortedTrovesProxyAddr),
        //     ITroveManager(cpTroveManagerProxyAddr),
        //     ILiquidationManager(cpLiquidationManagerProxyAddr)
        // );
        // assert(cpFactoryAddr == address(factory));

        // // Deploy proxy contracts
        // bytes memory data;
        // address proxy;

        // // SortedTroves
        // data = abi.encodeCall(ISortedTroves.initialize, (IPrismaCore(cpPrismaCoreAddr)));
        // proxy = address(new ERC1967Proxy(address(sortedTrovesImpl), data));
        // assert(proxy == cpSortedTrovesProxyAddr);

        // // PriceFeedAggregator
        // OracleSetup[] memory oracleSetups = new OracleSetup[](0); // empty array
        // data = abi.encodeCall(
        //     IPriceFeedAggregator.initialize,
        //     (IPrismaCore(cpPrismaCoreAddr), IPriceFeed(NATIVE_TOKEN_PRICE_FEED), oracleSetups)
        // );
        // proxy = address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data));
        // assert(proxy == cpPriceFeedAggregatorProxyAddr);

        // // BorrowerOperations
        // data = abi.encodeCall(
        //     IBorrowerOperations.initialize,
        //     (
        //         IPrismaCore(cpPrismaCoreAddr),
        //         IDebtToken(cpDebtTokenAddr),
        //         IFactory(cpFactoryAddr),
        //         BO_MIN_NET_DEBT,
        //         GAS_COMPENSATION
        //     )
        // );
        // proxy = address(new ERC1967Proxy(address(borrowerOperationsImpl), data));
        // assert(proxy == cpBorrowerOperationsProxyAddr);

        // // LiquidationManager
        // data = abi.encodeCall(
        //     ILiquidationManager.initialize,
        //     (
        //         IPrismaCore(cpPrismaCoreAddr),
        //         IStabilityPool(cpStabilityPoolProxyAddr),
        //         IBorrowerOperations(cpBorrowerOperationsProxyAddr),
        //         IFactory(cpFactoryAddr),
        //         GAS_COMPENSATION
        //     )
        // );
        // proxy = address(new ERC1967Proxy(address(liquidationManagerImpl), data));
        // assert(proxy == cpLiquidationManagerProxyAddr);

        // // StabilityPool
        // data = abi.encodeCall(
        //     IStabilityPool.initialize,
        //     (
        //         IPrismaCore(cpPrismaCoreAddr),
        //         IDebtToken(cpDebtTokenAddr),
        //         IFactory(cpFactoryAddr),
        //         ILiquidationManager(cpLiquidationManagerProxyAddr)
        //     )
        // );
        // proxy = address(new ERC1967Proxy(address(stabilityPoolImpl), data));
        // assert(proxy == cpStabilityPoolProxyAddr);

        // // TroveManager
        // data = abi.encodeCall(
        //     ITroveManager.initialize,
        //     (
        //         IPrismaCore(cpPrismaCoreAddr),
        //         IGasPool(cpGasPoolAddr),
        //         IDebtToken(cpDebtTokenAddr),
        //         IBorrowerOperations(cpBorrowerOperationsProxyAddr),
        //         ILiquidationManager(cpLiquidationManagerProxyAddr),
        //         IPriceFeedAggregator(cpPriceFeedAggregatorProxyAddr),
        //         GAS_COMPENSATION
        //     )
        // );
        // proxy = address(new ERC1967Proxy(address(troveManagerImpl), data));
        // assert(proxy == cpTroveManagerProxyAddr);

        vm.stopPrank();
    }
}
