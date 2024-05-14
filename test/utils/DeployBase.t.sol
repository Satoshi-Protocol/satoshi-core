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
import {OSHIToken} from "../../src/OSHI/OSHIToken.sol";
import {SLPTokenTester} from "../../test/SLPTokenTester.sol";
import {MockUniswapV2ERC20} from "../../test/MockUniswapV2ERC20.sol";
import {Factory, DeploymentParams} from "../../src/core/Factory.sol";
import {CommunityIssuance} from "../../src/OSHI/CommunityIssuance.sol";
import {RoundData, OracleMock} from "../../src/mocks/OracleMock.sol";
import {PriceFeedChainlink} from "../../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";
import {RewardManager} from "../../src/OSHI/RewardManager.sol";
import {ReferralManager} from "../../src/helpers/ReferralManager.sol";
import {SatoshiLPFactory} from "../../src/SLP/SatoshiLPFactory.sol";
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
import {IOSHIToken} from "../../src/interfaces/core/IOSHIToken.sol";
import {IFactory} from "../../src/interfaces/core/IFactory.sol";
import {ICommunityIssuance} from "../../src/interfaces/core/ICommunityIssuance.sol";
import {IPriceFeed} from "../../src/interfaces/dependencies/IPriceFeed.sol";
import {IRewardManager} from "../../src/interfaces/core/IRewardManager.sol";
import {ISatoshiBORouter} from "../../src/helpers/interfaces/ISatoshiBORouter.sol";
import {IReferralManager} from "../../src/helpers/interfaces/IReferralManager.sol";
import {ISatoshiLPFactory} from "../../src/interfaces/core/ISatoshiLPFactory.sol";
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
    _1_MILLION,
    SP_CLAIM_START_TIME
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
    uint256 rewardManagerDebtAmtBefore;
    uint256 gasPoolDebtAmtBefore;
    uint256 userBalanceBefore;
    uint256 userCollAmtBefore;
    uint256 userDebtAmtBefore;
    uint256 troveManagerCollateralAmtBefore;
    uint256 debtTokenTotalSupplyBefore;
    // after state vars
    uint256 rewardManagerDebtAmtAfter;
    uint256 gasPoolDebtAmtAfter;
    uint256 userBalanceAfter;
    uint256 userCollAmtAfter;
    uint256 userDebtAmtAfter;
    uint256 troveManagerCollateralAmtAfter;
    uint256 debtTokenTotalSupplyAfter;
}

abstract contract DeployBase is Test {
    /* mock contracts for testing */
    IWETH weth;
    IERC20 collateralMock;
    RoundData internal initRoundData;
    uint256 TM_ALLOCATION;
    uint256 SP_ALLOCATION;

    /* implementation contracts addresses */
    IPriceFeedAggregator priceFeedAggregatorImpl;
    IBorrowerOperations borrowerOperationsImpl;
    ILiquidationManager liquidationManagerImpl;
    IStabilityPool stabilityPoolImpl;
    ISortedTroves sortedTrovesImpl;
    ITroveManager troveManagerImpl;
    IRewardManager rewardManagerImpl;
    IDebtToken debtTokenImpl;
    IFactory factoryImpl;
    ICommunityIssuance communityIssuanceImpl;
    IOSHIToken oshiTokenImpl;
    ISatoshiLPFactory satoshiLPFactoryImpl;
    /* non-upgradeable contracts */
    IGasPool gasPool;
    ISatoshiCore satoshiCore;
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
    /* Beacon contracts */
    IBeacon sortedTrovesBeacon;
    IBeacon troveManagerBeacon;
    /* DebtTokenTester contract */
    SLPTokenTester slpTokenTester;

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
    // Mock oracle
    address oracleMockAddr;

    function setUp() public virtual {
        // deploy WETH
        weth = IWETH(_deployWETH(DEPLOYER));
        // deploy ERC20
        collateralMock = new ERC20("Collateral", "COLL");
        initRoundData = RoundData({
            answer: 4000000000000,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });

        TM_ALLOCATION = 20 * _1_MILLION;
        SP_ALLOCATION = 10 * _1_MILLION;
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

        _setConfigByOwner(owner, troveManagerBeaconProxy);

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
        cpRewardManagerImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpOshiTokenImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiLPFactoryImplAddr = vm.computeCreateAddress(deployer, ++nonce);
        // non-upgradeable contracts
        cpGasPoolAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiCoreAddr = vm.computeCreateAddress(deployer, ++nonce);
        // UUPS proxy contracts
        cpPriceFeedAggregatorProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpBorrowerOperationsProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpLiquidationManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpStabilityPoolProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpRewardManagerProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpDebtTokenProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpFactoryProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpCommunityIssuanceProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpOshiTokenProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
        cpSatoshiLPFactoryProxyAddr = vm.computeCreateAddress(deployer, ++nonce);
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
        assert(rewardManagerImpl == IRewardManager(address(0)));
        assert(debtTokenImpl == IDebtToken(address(0)));
        assert(factoryImpl == IFactory(address(0)));
        assert(communityIssuanceImpl == ICommunityIssuance(address(0)));
        assert(oshiTokenImpl == IOSHIToken(address(0)));
        assert(satoshiLPFactoryImpl == ISatoshiLPFactory(address(0)));

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

        vm.stopPrank();
    }

    function _deployNonUpgradeableContracts(address deployer) internal {
        _deployGasPool(deployer);
        _deploySatoshiCore(deployer);
    }

    function _deployUUPSUpgradeableContracts(address deployer) internal {
        _deployPriceFeedAggregatorProxy(deployer);
        _deployBorrowerOperationsProxy(deployer);
        _deployLiquidationManagerProxy(deployer);
        _deployStabilityPoolProxy(deployer);
        _deployRewardManagerProxy(deployer);
        _deployDebtTokenProxy(deployer);
        _deployFactoryProxy(deployer);
        _deployCommunityIssuanceProxy(deployer);
        _deployOSHITokenProxy(deployer);
        _deploySatoshiLPFactoryProxy(deployer);
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
        oracleMockAddr = _deployOracleMock(deployer, decimals, version);
        // update data to the oracle mock
        _updateRoundData(deployer, oracleMockAddr, roundData);

        assert(satoshiCore != ISatoshiCore(address(0)));
        // deploy price feed chainlink contract
        return _deployPriceFeedChainlink(deployer, AggregatorV3Interface(oracleMockAddr), satoshiCore);
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
        satoshiCore = new SatoshiCore(OWNER, GUARDIAN, FEE_RECEIVER, REWARD_MANAGER);
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
                IDebtToken(cpDebtTokenProxyAddr),
                IFactory(cpFactoryProxyAddr),
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
                IFactory(cpFactoryProxyAddr),
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
                IDebtToken(cpDebtTokenProxyAddr),
                IFactory(cpFactoryProxyAddr),
                ILiquidationManager(cpLiquidationManagerProxyAddr),
                ICommunityIssuance(cpCommunityIssuanceProxyAddr)
            )
        );
        stabilityPoolProxy = IStabilityPool(address(new ERC1967Proxy(address(stabilityPoolImpl), data)));
        vm.stopPrank();
    }

    function _deployRewardManagerProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(rewardManagerImpl != IRewardManager(address(0))); // check if implementation contract is deployed
        assert(rewardManagerProxy == IRewardManager(address(0))); // check if proxy contract is not deployed
        bytes memory data = abi.encodeCall(IRewardManager.initialize, (ISatoshiCore(cpSatoshiCoreAddr)));
        rewardManagerProxy = IRewardManager(address(new ERC1967Proxy(address(rewardManagerImpl), data)));
        vm.stopPrank();
    }

    function _deployDebtTokenProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(debtTokenImpl != IDebtToken(address(0))); // check if debt token contract is not deployed
        assert(debtTokenProxy == IDebtToken(address(0))); // check if debt token proxy contract is not deployed
        bytes memory data = abi.encodeCall(
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
        debtTokenProxy = IDebtToken(address(new ERC1967Proxy(address(debtTokenImpl), data)));
        vm.stopPrank();
    }

    function _deployFactoryProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(factoryImpl != IFactory(address(0))); // check if factory contract is not deployed
        assert(factoryProxy == IFactory(address(0))); // check if factory proxy contract is not deployed
        bytes memory data = abi.encodeCall(
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
        factoryProxy = IFactory(address(new ERC1967Proxy(address(factoryImpl), data)));
        vm.stopPrank();
    }

    function _deployCommunityIssuanceProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(communityIssuanceImpl != ICommunityIssuance(address(0))); // check if community issuance contract is not deployed
        assert(communityIssuanceProxy == ICommunityIssuance(address(0))); // check if community issuance proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            ICommunityIssuance.initialize,
            (
                ISatoshiCore(cpSatoshiCoreAddr),
                IOSHIToken(cpOshiTokenProxyAddr),
                IStabilityPool(cpStabilityPoolProxyAddr)
            )
        );
        communityIssuanceProxy = ICommunityIssuance(address(new ERC1967Proxy(address(communityIssuanceImpl), data)));
        vm.stopPrank();
    }

    function _deployOSHITokenProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(oshiTokenImpl != IOSHIToken(address(0))); // check if oshi token contract is not deployed
        assert(oshiTokenProxy == IOSHIToken(address(0))); // check if oshi token proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            IOSHIToken.initialize, (ISatoshiCore(cpSatoshiCoreAddr))
        );
        oshiTokenProxy = IOSHIToken(address(new ERC1967Proxy(address(oshiTokenImpl), data)));
        vm.stopPrank();
    }

    function _deploySatoshiLPFactoryProxy(address deployer) internal {
        vm.startPrank(deployer);
        assert(satoshiLPFactoryImpl != ISatoshiLPFactory(address(0))); // check if satoshi LP factory contract is not deployed
        assert(satoshiLPFactoryProxy == ISatoshiLPFactory(address(0))); // check if satoshi LP factory proxy contract is not deployed
        bytes memory data = abi.encodeCall(
            ISatoshiLPFactory.initialize,
            (ISatoshiCore(cpSatoshiCoreAddr), ICommunityIssuance(cpCommunityIssuanceProxyAddr))
        );
        satoshiLPFactoryProxy = ISatoshiLPFactory(address(new ERC1967Proxy(address(satoshiLPFactoryImpl), data)));
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

    function _deployPriceFeedChainlink(address deployer, AggregatorV3Interface oracle, ISatoshiCore _satoshiCore)
        internal
        returns (address)
    {
        vm.startPrank(deployer);
        assert(oracle != AggregatorV3Interface(address(0))); // check if oracle contract is deployed
        address priceFeedChainlinkAddr = address(new PriceFeedChainlink(oracle, _satoshiCore));
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

        uint64 nonce = vm.getNonce(address(factoryProxy));
        address cpSortedTrovesBeaconProxyAddr = vm.computeCreateAddress(address(factoryProxy), nonce);
        address cpTroveManagerBeaconProxyAddr = vm.computeCreateAddress(address(factoryProxy), ++nonce);

        // check NewDeployment event
        vm.expectEmit(true, true, true, true, address(factoryProxy));
        emit NewDeployment(
            collateral,
            priceFeed,
            ITroveManager(cpTroveManagerBeaconProxyAddr),
            ISortedTroves(cpSortedTrovesBeaconProxyAddr)
        );

        factoryProxy.deployNewInstance(collateral, priceFeed, deploymentParams);

        vm.stopPrank();

        return (ISortedTroves(cpSortedTrovesBeaconProxyAddr), ITroveManager(cpTroveManagerBeaconProxyAddr));
    }

    /* ============ Deploy Helper Contracts ============ */

    function _deployHintHelpers(address deployer) internal returns (address) {
        vm.startPrank(deployer);
        assert(borrowerOperationsProxy != IBorrowerOperations(address(0))); // check if borrower operations proxy contract is deployed
        address hintHelpersAddr = address(new MultiCollateralHintHelpers(borrowerOperationsProxy, GAS_COMPENSATION));
        vm.stopPrank();

        return hintHelpersAddr;
    }

    function _deployWETH(address deployer) internal returns (address) {
        vm.startPrank(deployer);
        address wethAddr = address(new WETH9());
        vm.stopPrank();

        return wethAddr;
    }

    function _deploySatoshiBORouter(address deployer, IReferralManager referralManager) internal returns (address) {
        vm.startPrank(deployer);
        assert(debtTokenProxy != IDebtToken(address(0))); // check if debt token contract is deployed
        assert(borrowerOperationsProxy != IBorrowerOperations(address(0))); // check if borrower operations proxy contract is deployed
        assert(referralManager != IReferralManager(address(0))); // check if referral manager contract is not zero address
        assert(weth != IWETH(address(0))); // check if WETH contract is deployed
        address satoshiBORouterAddr =
            address(new SatoshiBORouter(debtTokenProxy, borrowerOperationsProxy, referralManager, weth));
        vm.stopPrank();

        return satoshiBORouterAddr;
    }

    /* ============ Set Config by Owner after Deployments ============ */

    function _setConfigByOwner(address owner, ITroveManager troveManagerBeaconProxy) internal {
        // set allocation for the stability pool
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(stabilityPoolProxy);
        uint256[] memory _amount = new uint256[](1);
        _amount[0] = SP_ALLOCATION;
        _setRewardManager(owner, address(rewardManagerProxy));
        _setTMCommunityIssuanceAllocation(owner, troveManagerBeaconProxy);
        _setSPCommunityIssuanceAllocation(owner);
        _setAddress(owner, borrowerOperationsProxy, weth, debtTokenProxy, oshiTokenProxy);
        _registerTroveManager(owner, troveManagerBeaconProxy);
        _setClaimStartTime(owner, SP_CLAIM_START_TIME);
        _setSPRewardRate(owner);
        _setTMRewardRate(owner, troveManagerBeaconProxy);
    }

    function _registerTroveManager(address owner, ITroveManager _troveManager) internal {
        vm.startPrank(owner);
        rewardManagerProxy.registerTroveManager(_troveManager);
        vm.stopPrank();
    }

    function _setRewardManager(address owner, address _rewardManagerProxy) internal {
        vm.startPrank(owner);
        satoshiCore.setRewardManager(_rewardManagerProxy);
        vm.stopPrank();
    }

    function _setTMCommunityIssuanceAllocation(address owner, ITroveManager troveManagerBeaconProxy) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = address(troveManagerBeaconProxy);
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = TM_ALLOCATION;
        vm.startPrank(owner);
        communityIssuanceProxy.setAllocated(_recipients, _amounts);
        vm.stopPrank();
    }

    function _setSPCommunityIssuanceAllocation(address owner) internal {
        address[] memory _recipients = new address[](1);
        _recipients[0] = cpStabilityPoolProxyAddr;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = SP_ALLOCATION;
        vm.startPrank(owner);
        communityIssuanceProxy.setAllocated(_recipients, _amounts);
        vm.stopPrank();
    }

    function _setAddress(
        address owner,
        IBorrowerOperations _borrowerOperations,
        IWETH _weth,
        IDebtToken _debtToken,
        IOSHIToken _oshiToken
    ) internal {
        vm.startPrank(owner);
        rewardManagerProxy.setAddresses(_borrowerOperations, _weth, _debtToken, _oshiToken);
        vm.stopPrank();
    }

    function _setClaimStartTime(address owner, uint32 _claimStartTime) internal {
        vm.startPrank(owner);
        stabilityPoolProxy.setClaimStartTime(_claimStartTime);
        vm.stopPrank();
    }

    function _setSPRewardRate(address owner) internal {
        vm.startPrank(owner);
        stabilityPoolProxy.setRewardRate(stabilityPoolProxy.MAX_REWARD_RATE());
        vm.stopPrank();
    }

    function _setTMRewardRate(address owner, ITroveManager troveManagerBeaconProxy) internal {
        vm.startPrank(owner);
        uint128[] memory numerator = new uint128[](1);
        numerator[0] = 1;
        factoryProxy.setRewardRate(numerator, 1);
        assertEq(troveManagerBeaconProxy.rewardRate(), factoryProxy.maxRewardRate());
        vm.stopPrank();
    }

    /* ============ Deploy TokenTester Contracts ============ */
    function _deployReferralManager(address deployer, ISatoshiBORouter satoshiBORouter) internal returns (address) {
        vm.startPrank(deployer);
        assert(satoshiBORouter != ISatoshiBORouter(address(0))); // check if satoshiBORouter contract is not zero address
        uint256 startTimestamp = block.timestamp;
        uint256 endTimestamp = startTimestamp + 30 days;
        address referralManagerAddr = address(new ReferralManager(satoshiBORouter, startTimestamp, endTimestamp));
        assert(IReferralManager(referralManagerAddr).satoshiBORouter() == satoshiBORouter);
        assert(IReferralManager(referralManagerAddr).startTimestamp() == startTimestamp);
        assert(IReferralManager(referralManagerAddr).endTimestamp() == endTimestamp);
        assert(IReferralManager(referralManagerAddr).getTotalPoints() == 0);
        vm.stopPrank();

        return referralManagerAddr;
    }

    /* ============ Deploy DebtTokenTester Contracts ============ */

    function _deploySLPTokenTester(IERC20 lpToken) internal {
        vm.startPrank(DEPLOYER);
        slpTokenTester = new SLPTokenTester(satoshiCore, lpToken, communityIssuanceProxy);
        vm.stopPrank();
    }

    function _deployMockUniV2Token() internal returns (address mockUniV2TokenAddr) {
        vm.startPrank(DEPLOYER);
        mockUniV2TokenAddr = address(new MockUniswapV2ERC20());
        vm.stopPrank();
    }

    function _deploySLPToken(IERC20 lpToken) internal returns (address slpTokenAddr) {
        vm.startPrank(OWNER);
        slpTokenAddr = satoshiLPFactoryProxy.createSLP("SLP", "SLP", lpToken, 100);
        vm.stopPrank();
    }
}
