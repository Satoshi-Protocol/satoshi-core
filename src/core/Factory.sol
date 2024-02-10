// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISortedTroves} from "../interfaces/core/ISortedTroves.sol";
import {IStabilityPool} from "../interfaces/core/IStabilityPool.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {DeploymentParams, IFactory} from "../interfaces/core/IFactory.sol";
import {IGasPool} from "../interfaces/core/IGasPool.sol";
import {IPriceFeedAggregator} from "../interfaces/core/IPriceFeedAggregator.sol";

//NOTE: non-upgradeable Factory contract

contract Factory is IFactory, SatoshiOwnable {
    ISatoshiCore public immutable satoshiCore;
    IDebtToken public immutable debtToken;
    IGasPool public immutable gasPool;
    IPriceFeedAggregator public immutable priceFeedAggregatorProxy;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    ILiquidationManager public immutable liquidationManagerProxy;
    IStabilityPool public immutable stabilityPoolProxy;
    IBeacon public immutable sortedTrovesBeacon;
    IBeacon public immutable troveManagerBeacon;
    uint256 public immutable gasCompensation;

    ITroveManager[] public troveManagers;

    constructor(
        ISatoshiCore _satoshiCore,
        IDebtToken _debtToken,
        IGasPool _gasPool,
        IPriceFeedAggregator _priceFeedAggregatorProxy,
        IBorrowerOperations _borrowerOperationsProxy,
        ILiquidationManager _liquidationManagerProxy,
        IStabilityPool _stabilityPoolProxy,
        IBeacon _sortedTrovesBeacon,
        IBeacon _troveManagerBeacon,
        uint256 _gasCompensation
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        satoshiCore = _satoshiCore;
        debtToken = _debtToken;
        gasPool = _gasPool;
        priceFeedAggregatorProxy = _priceFeedAggregatorProxy;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        liquidationManagerProxy = _liquidationManagerProxy;
        stabilityPoolProxy = _stabilityPoolProxy;
        sortedTrovesBeacon = _sortedTrovesBeacon;
        troveManagerBeacon = _troveManagerBeacon;
        gasCompensation = _gasCompensation;
    }

    function troveManagerCount() external view returns (uint256) {
        return troveManagers.length;
    }

    function deployNewInstance(IERC20 collateralToken, IPriceFeed priceFeed, DeploymentParams memory params)
        external
        onlyOwner
    {
        ISortedTroves sortedTrovesBeaconProxy = _deploySortedTrovesBeaconProxy();
        ITroveManager troveManagerBeaconProxy = _deployTroveManagerBeaconProxy();
        troveManagers.push(troveManagerBeaconProxy);

        sortedTrovesBeaconProxy.setConfig(troveManagerBeaconProxy);
        troveManagerBeaconProxy.setConfig(sortedTrovesBeaconProxy, collateralToken);

        // verify that the oracle is correctly working
        troveManagerBeaconProxy.fetchPrice();

        debtToken.enableTroveManager(troveManagerBeaconProxy);
        stabilityPoolProxy.enableCollateral(collateralToken);
        borrowerOperationsProxy.configureCollateral(troveManagerBeaconProxy, collateralToken);
        liquidationManagerProxy.enableTroveManager(troveManagerBeaconProxy);

        troveManagerBeaconProxy.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR
        );

        emit NewDeployment(collateralToken, priceFeed, troveManagerBeaconProxy, sortedTrovesBeaconProxy);
    }

    function _deploySortedTrovesBeaconProxy() internal returns (ISortedTroves) {
        bytes memory data = abi.encodeCall(ISortedTroves.initialize, satoshiCore);
        return ISortedTroves(address(new BeaconProxy(address(sortedTrovesBeacon), data)));
    }

    function _deployTroveManagerBeaconProxy() internal returns (ITroveManager) {
        bytes memory data = abi.encodeCall(
            ITroveManager.initialize,
            (
                satoshiCore,
                gasPool,
                debtToken,
                borrowerOperationsProxy,
                liquidationManagerProxy,
                priceFeedAggregatorProxy,
                gasCompensation
            )
        );
        return ITroveManager(address(new BeaconProxy(address(troveManagerBeacon), data)));
    }
}
