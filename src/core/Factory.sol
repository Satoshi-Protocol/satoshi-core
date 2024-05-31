// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";
import {IRewardManager} from "../interfaces/core/IRewardManager.sol";

/**
 * @title Factory Contract (Non-upgradeable)
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/Factory.sol
 *
 */
contract Factory is IFactory, SatoshiOwnable, UUPSUpgradeable {
    ISatoshiCore public satoshiCore;
    IDebtToken public debtToken;
    IGasPool public gasPool;
    IPriceFeedAggregator public priceFeedAggregatorProxy;
    IBorrowerOperations public borrowerOperationsProxy;
    ILiquidationManager public liquidationManagerProxy;
    IStabilityPool public stabilityPoolProxy;
    IBeacon public sortedTrovesBeacon;
    IBeacon public troveManagerBeacon;
    uint256 public gasCompensation;
    ICommunityIssuance public communityIssuance;
    ITroveManager[] public troveManagers;

    uint128 public constant maxRewardRate = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(
        ISatoshiCore _satoshiCore,
        IDebtToken _debtToken,
        IGasPool _gasPool,
        IPriceFeedAggregator _priceFeedAggregatorProxy,
        IBorrowerOperations _borrowerOperationsProxy,
        ILiquidationManager _liquidationManagerProxy,
        IStabilityPool _stabilityPoolProxy,
        IBeacon _sortedTrovesBeacon,
        IBeacon _troveManagerBeacon,
        ICommunityIssuance _communityIssuance,
        uint256 _gasCompensation
    ) external initializer {
        __UUPSUpgradeable_init_unchained();
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
        communityIssuance = _communityIssuance;
    }

    function troveManagerCount() external view returns (uint256) {
        return troveManagers.length;
    }

    function deployNewInstance(IERC20 collateralToken, IPriceFeed priceFeed, DeploymentParams calldata params)
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
            params.MCR,
            params.rewardRate,
            params.claimStartTime
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
                communityIssuance,
                gasCompensation
            )
        );
        return ITroveManager(address(new BeaconProxy(address(troveManagerBeacon), data)));
    }

    function setRewardRate(uint128[] calldata _numerator, uint128 _denominator) external onlyOwner {
        require(_numerator.length == troveManagers.length, "Factory: invalid length");
        uint128 totalRewardRate;
        for (uint256 i; i < _numerator.length; ++i) {
            uint128 troveRewardRate = _numerator[i] * maxRewardRate / _denominator;
            totalRewardRate += troveRewardRate;
            troveManagers[i].setRewardRate(troveRewardRate);
        }
        require(totalRewardRate <= maxRewardRate, "Factory: invalid total reward rate");
    }
}
