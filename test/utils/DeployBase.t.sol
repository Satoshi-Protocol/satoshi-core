// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {MultiCollateralHintHelpers} from "../../src/helpers/MultiCollateralHintHelpers.sol";
import {WETH9} from "../../src/mocks/WETH9.sol";
import {SatoshiBORouter} from "../../src/helpers/SatoshiBORouter.sol";
import {SortedTroves} from "../../src/core/SortedTroves.sol";
import {PriceFeedAggregator} from "../../src/core/PriceFeedAggregator.sol";
import {BorrowerOperations} from "../../src/core/BorrowerOperations.sol";
import {LiquidationManager} from "../../src/core/LiquidationManager.sol";
import {StabilityPool} from "../../src/core/StabilityPool.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {GasPool} from "../../src/core/GasPool.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {DebtToken} from "../../src/core/DebtToken.sol";
import {Factory, DeploymentParams} from "../../src/core/Factory.sol";
import {RoundData, OracleMock} from "../../src/mocks/OracleMock.sol";
import {PriceFeedChainlink} from "../../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {IWETH} from "../../src/helpers/interfaces/IWETH.sol";
import {ISortedTroves} from "../../src/interfaces/core/ISortedTroves.sol";
import {IPriceFeedAggregator} from "../../src/interfaces/core/IPriceFeedAggregator.sol";
import {IBorrowerOperations} from "../../src/interfaces/core/IBorrowerOperations.sol";
import {ILiquidationManager} from "../../src/interfaces/core/ILiquidationManager.sol";
import {IStabilityPool} from "../../src/interfaces/core/IStabilityPool.sol";
import {ITroveManager} from "../../src/interfaces/core/ITroveManager.sol";
import {IGasPool} from "../../src/interfaces/core/IGasPool.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {IDebtToken} from "../../src/interfaces/core/IDebtToken.sol";
import {IFactory} from "../../src/interfaces/core/IFactory.sol";
import {IPriceFeed} from "../../src/interfaces/dependencies/IPriceFeed.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    FEE_RECEIVER,
    DEBT_TOKEN_NAME,
    DEBT_TOKEN_SYMBOL,
    GAS_COMPENSATION,
    BO_MIN_NET_DEBT
} from "../TestConfig.sol";

struct LocalVars {
    // base vars
    uint256 collAmt;
    uint256 debtAmt;
    uint256 maxFeePercentage;
    uint256 borrowingFee;
    uint256 compositeDebt;
    uint256 totalCollAmt;
    uint256 totalNetDebtAmt;
    uint256 totalDebt;
    uint256 stake;
    uint256 NICR;
    address upperHint;
    address lowerHint;
    // change trove state vars
    uint256 addCollAmt;
    uint256 withdrawCollAmt;
    uint256 repayDebtAmt;
    uint256 withdrawDebtAmt;
    //before state vars
    uint256 feeReceiverDebtAmtBefore;
    uint256 gasPoolDebtAmtBefore;
    uint256 userBalanceBefore;
    uint256 userCollAmtBefore;
    uint256 userDebtAmtBefore;
    uint256 troveManagerCollateralAmtBefore;
    uint256 debtTokenTotalSupplyBefore;
    // after state vars
    uint256 feeReceiverDebtAmtAfter;
    uint256 gasPoolDebtAmtAfter;
    uint256 userBalanceAfter;
    uint256 userCollAmtAfter;
    uint256 userDebtAmtAfter;
    uint256 troveManagerCollateralAmtAfter;
    uint256 debtTokenTotalSupplyAfter;
}

abstract contract DeployBase is Test {
    /* mock contracts for testing */
    IERC20 collateralMock;

    /* implementation contracts addresses */
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ISortedTroves sortedTrovesImpl;
    ITroveManager troveManagerImpl;
    /* non-upgradeable contracts */
    IGasPool gasPool;
    ISatoshiCore satoshiCore;
    IDebtToken debtToken;
    IFactory factory;
    /* UUPS proxy contracts */
    IPriceFeedAggregator priceFeedAggregatorProxy;
    IBorrowerOperations borrowerOperationsProxy;
    ILiquidationManager liquidationManagerProxy;
    IStabilityPool stabilityPoolProxy;
    /* Beacon contracts */
    IBeacon sortedTrovesBeacon;
    IBeacon troveManagerBeacon;

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
    // UUPS proxy contracts
    address cpPriceFeedAggregatorProxyAddr;
    address cpBorrowerOperationsProxyAddr;
    address cpLiquidationManagerProxyAddr;
    address cpStabilityPoolProxyAddr;
    // Beacon contracts
    address cpSortedTrovesBeaconAddr;
    address cpTroveManagerBeaconAddr;

    function setUp() public virtual {
        // deploy ERC20
        collateralMock = new ERC20("Collateral", "COLL");
    }

    function _deploySetupAndInstance(
        address deployer,
        address owner,
        uint8 oracleMock_decimals,
        uint256 oracleMock_version,
        RoundData memory oracleMock_roundData,
        IERC20 collateral,
        DeploymentParams memory deploymentParams
    ) internal returns (ISortedTroves, ITroveManager) {
        _computeContractsAddress(deployer);
        _deployImplementationContracts(deployer);
        _deployNonUpgradeableContracts(deployer);
        _deployUUPSUpgradeableContracts(deployer);
        _deployBeaconContracts(deployer);

        address priceFeedAddr =
            _deployPriceFeed(deployer, oracleMock_decimals, oracleMock_version, oracleMock_roundData);
        _setPriceFeedToPriceFeedAggregatorProxy(owner, collateral, IPriceFeed(priceFeedAddr));

        (ISortedTroves sortedTrovesBeaconProxy, ITroveManager troveManagerBeaconProxy) =
            _deployNewInstance(owner, collateral, IPriceFeed(priceFeedAddr), deploymentParams);

        return (sortedTrovesBeaconProxy, troveManagerBeaconProxy);
    }

    function _computeContractsAddress(address deployer) internal {
        // Get nonce for computing contracts address
        uint64 nonce = vm.getNonce(deployer);

        /* computed contracts address for deployment */
        // implementation contracts
        cpSortedTrovesImplAddr = vm.computeCreateAddress(deployer, nonce);
        cpPriceFeedAggregatorImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryAddr = vm.computeCreateAddress(deployer, ++nonce);
        // UUPS proxy contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        // Beacon contracts
        cpSortedTrovesBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpTroveManagerBeaconAddr = vm.computeCreateAddress(deployer, ++nonce);
    }

    function _deployImplementationContracts(address deployer) internal {
        vm.startPrank(deployer);

        // check if implementation contracts are not deployed
        assert(priceFeedAggregatorImpl == IPriceFeedAggregator(address(0)));
        assert(borrowerOperationsImpl == IBorrowerOperations(address(0)));
        assert(liquidationManagerImpl == ILiquidationManager(address(0)));
        assert(stabilityPoolImpl == IStabilityPool(address(0)));
        assert(sortedTrovesImpl == ISortedTroves(address(0)));
        assert(troveManagerImpl == ITroveManager(address(0)));

        priceFeedAggregatorImpl = new PriceFeedAggregator();
        borrowerOperationsImpl = new BorrowerOperations();
        liquidationManagerImpl = new LiquidationManager();
        stabilityPoolImpl = new StabilityPool();
        sortedTrovesImpl = new SortedTroves();
        troveManagerImpl = new TroveManager();

        vm.stopPrank();
    }

    function _deployNonUpgradeableContracts(address deployer) internal {
        _deployGasPool(deployer);
        _deploySatoshiCore(deployer);
        _deployDebtToken(deployer);
        _deployFactory(deployer);
    }

    function _deployUUPSUpgradeableContracts(address deployer) internal {
        _deployPriceFeedAggregatorProxy(deployer);
        _deployBorrowerOperationsProxy(deployer);
        _deployLiquidationManagerProxy(deployer);
        _deployStabilityPoolProxy(deployer);
    }

    function _deployBeaconContracts(address deployer) internal {
        _deploySortedTrovesBeacon(deployer);
        _deployTroveManagerBeacon(deployer);
    }

    function _deployPriceFeed(address deployer, uint8 decimals, uint256 version, RoundData memory roundData)
        internal
        returns (address)
    {
        // deploy oracle mock contract to mcok price feed source
        address oracleMockAddr = _deployOracleMock(deployer, decimals, version);
        // update data to the oracle mock
        _updateRoundData(deployer, oracleMockAddr, roundData);

        // deploy price feed chainlink contract
        return _deployPriceFeedChainlink(deployer, AggregatorV3Interface(oracleMockAddr));
    }

    /* ============ Deploy Non-upgradeable Contracts ============ */

    function _deployGasPool(address deployer) internal {
        vm.startPrank(deployer);
        assert(gasPool == IGasPool(address(0))); // check if gas pool contract is not deployed
        gasPool = new GasPool();
        vm.stopPrank();
    }

    function _deploySatoshiCore(address deployer) internal {
        vm.startPrank(deployer);
        assert(gasPool != IGasPool(address(0))); // check if gas pool contract is deployed
        satoshiCore = new SatoshiCore(OWNER, GUARDIAN, FEE_RECEIVER);
        vm.stopPrank();
    }

    function _deployDebtToken(address deployer) internal {
        vm.startPrank(deployer);
        assert(debtToken == IDebtToken(address(0))); // check if debt token contract is not deployed
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
        vm.stopPrank();
    }

    function _deployFactory(address deployer) internal {
        vm.startPrank(deployer);
        assert(factory == IFactory(address(0))); // check if factory contract is not deployed
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
            GAS_COMPENSATION
        );
        vm.stopPrank();
    }

    /* ============ Deploy UUPS Proxies ============ */

    function _deployPriceFeedAggregatorProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(priceFeedAggregatorImpl != IPriceFeedAggregator(address(0))); // check if implementation contract is deployed
        assert(priceFeedAggregatorProxy == IPriceFeedAggregator(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(IPriceFeedAggregator.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        priceFeedAggregatorProxy =
            IPriceFeedAggregator(address(new ERC1967Proxy(address(priceFeedAggregatorImpl), data)));
        vm.stopPrank();
    }

    function _deployBorrowerOperationsProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(borrowerOperationsImpl != IBorrowerOperations(address(0))); // check if implementation contract is deployed
        assert(borrowerOperationsProxy == IBorrowerOperations(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            IBorrowerOperations.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                BO_MIN_NET_DEBT,
                GAS_COMPENSATION
            )
        );
        borrowerOperationsProxy = IBorrowerOperations(address(new ERC1967Proxy(address(borrowerOperationsImpl), data)));
        vm.stopPrank();
    }

    function _deployLiquidationManagerProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(liquidationManagerImpl != ILiquidationManager(address(0))); // check if implementation contract is deployed
        assert(liquidationManagerProxy == ILiquidationManager(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            ILiquidationManager.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IStabilityPool(cpStabilityPoolProxyAddr),
                IBorrowerOperations(cpBorrowerOperationsProxyAddr),
                IFactory(cpFactoryAddr),
                GAS_COMPENSATION
            )
        );
        liquidationManagerProxy = ILiquidationManager(address(new ERC1967Proxy(address(liquidationManagerImpl), data)));
        vm.stopPrank();
    }

    function _deployStabilityPoolProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(stabilityPoolImpl != IStabilityPool(address(0))); // check if implementation contract is deployed
        assert(stabilityPoolProxy == IStabilityPool(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            IStabilityPool.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IDebtToken(cpDebtTokenAddr),
                IFactory(cpFactoryAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr)
            )
        );
        stabilityPoolProxy = IStabilityPool(address(new ERC1967Proxy(address(stabilityPoolImpl), data)));
        vm.stopPrank();
    }

    /* ============ Deploy Beacon Contracts ============ */

    function _deploySortedTrovesBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(sortedTrovesImpl != ISortedTroves(address(0))); // check if implementation contract is deployed
        assert(sortedTrovesBeacon == UpgradeableBeacon(address(0))); // check if beacon contract is not deployed
        sortedTrovesBeacon = new UpgradeableBeacon(address(sortedTrovesImpl));
        vm.stopPrank();
    }

    function _deployTroveManagerBeacon(address deployer) internal {
        vm.startPrank(deployer);
        assert(troveManagerImpl != ITroveManager(address(0))); // check if implementation contract is deployed
        assert(troveManagerBeacon == UpgradeableBeacon(address(0))); // check if beacon contract is not deployed
        troveManagerBeacon = new UpgradeableBeacon(address(troveManagerImpl));
        vm.stopPrank();
    }

    /* ============ Before Deploy Instance ============ */

    function _deployOracleMock(address deployer, uint8 decimals, uint256 version) internal returns (address) {
        vm.startPrank(deployer);
        address oracleAddr = address(new OracleMock(decimals, version));
        vm.stopPrank();
        return oracleAddr;
    }

    function _updateRoundData(address caller, address oracleAddr, RoundData memory roundData) internal {
        vm.startPrank(caller);
        assert(oracleAddr != address(0)); // check if oracle contract is deployed
        OracleMock(oracleAddr).updateRoundData(roundData);
        vm.stopPrank();
    }

    function _deployPriceFeedChainlink(address deployer, AggregatorV3Interface oracle) internal returns (address) {
        vm.startPrank(deployer);
        assert(oracle != AggregatorV3Interface(address(0))); // check if oracle contract is deployed
        address priceFeedChainlinkAddr = address(new PriceFeedChainlink(oracle));
        vm.stopPrank();
        return priceFeedChainlinkAddr;
    }

    function _setPriceFeedToPriceFeedAggregatorProxy(address owner, IERC20 collateral, IPriceFeed priceFeed) internal {
        vm.startPrank(owner);
        priceFeedAggregatorProxy.setPriceFeed(collateral, priceFeed);
        vm.stopPrank();
    }

    /* ============ Deploy New Instance ============ */

    event NewDeployment(
        IERC20 indexed collateral, IPriceFeed priceFeed, ITroveManager troveManager, ISortedTroves sortedTroves
    );

    function _deployNewInstance(
        address owner,
        IERC20 collateral,
        IPriceFeed priceFeed,
        DeploymentParams memory deploymentParams
    ) internal returns (ISortedTroves, ITroveManager) {
        vm.startPrank(owner);

        uint64 nonce = vm.getNonce(address(factory));
        address cpSortedTrovesBeaconProxyAddr = vm.computeCreateAddress(address(factory), nonce);
        address cpTroveManagerBeaconProxyAddr = vm.computeCreateAddress(address(factory), ++nonce);

        // check NewDeployment event
        vm.expectEmit(true, true, true, true, address(factory));
        emit NewDeployment(
            collateral,
            priceFeed,
            ITroveManager(cpTroveManagerBeaconProxyAddr),
            ISortedTroves(cpSortedTrovesBeaconProxyAddr)
        );

        factory.deployNewInstance(collateral, priceFeed, deploymentParams);

        vm.stopPrank();

        return (ISortedTroves(cpSortedTrovesBeaconProxyAddr), ITroveManager(cpTroveManagerBeaconProxyAddr));
    }

    /* ============ Deploy Helper Contracts ============ */

    function _deployHintHelpers(address deployer) internal returns (address) {
        vm.startPrank(deployer);
        assert(borrowerOperationsProxy != IBorrowerOperations(address(0))); // check if borrower operations proxy contract is deployed
        address hintHelpersAddr =
            address(new MultiCollateralHintHelpers(address(borrowerOperationsProxy), GAS_COMPENSATION));
        vm.stopPrank();

        return hintHelpersAddr;
    }

    function _deployWETH(address deployer) internal returns (address) {
        vm.startPrank(deployer);
        address wethAddr = address(new WETH9());
        vm.stopPrank();

        return wethAddr;
    }

    function _deploySatoshiBORouter(address deployer, IWETH weth) internal returns (address) {
        vm.startPrank(deployer);
        assert(debtToken != IDebtToken(address(0))); // check if debt token contract is deployed
        assert(borrowerOperationsProxy != IBorrowerOperations(address(0))); // check if borrower operations proxy contract is deployed
        assert(weth != IWETH(address(0))); // check if WETH contract is deployed
        address satoshiBORouterAddr = address(new SatoshiBORouter(debtToken, borrowerOperationsProxy, weth));
        vm.stopPrank();

        return satoshiBORouterAddr;
    }
}
