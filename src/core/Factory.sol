// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ClonesUpgradeable as Clones} from "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";
import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {PrismaOwnable} from "../dependencies/PrismaOwnable.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISortedTroves} from "../interfaces/core/ISortedTroves.sol";
import {IStabilityPool} from "../interfaces/core/IStabilityPool.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";
import {IPrismaCore} from "../interfaces/core/IPrismaCore.sol";
import {DeploymentParams, IFactory} from "../interfaces/core/IFactory.sol";

//NOTE: non-upgradeable contract

/**
 * @title Prisma Trove Factory
 *     @notice Deploys cloned pairs of `TroveManager` and `SortedTroves` in order to
 *             add new collateral types within the system.
 */
contract Factory is IFactory, PrismaOwnable {
    using Clones for address;

    IDebtToken public immutable debtToken;
    IStabilityPool public immutable stabilityPool;
    ILiquidationManager public immutable liquidationManager;
    IBorrowerOperations public immutable borrowerOperations;
    ISortedTroves public immutable sortedTroves;
    ITroveManager public immutable troveManager;

    ITroveManager[] public troveManagers;

    constructor(
        IPrismaCore _prismaCore,
        IDebtToken _debtToken,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        ISortedTroves _sortedTroves,
        ITroveManager _troveManager,
        ILiquidationManager _liquidationManager
    ) {
        __PrismaOwnable_init(_prismaCore);
        debtToken = IDebtToken(_debtToken);
        stabilityPool = IStabilityPool(_stabilityPool);
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        sortedTroves = ISortedTroves(_sortedTroves);
        troveManager = ITroveManager(_troveManager);
        liquidationManager = ILiquidationManager(_liquidationManager);
    }

    function troveManagerCount() external view returns (uint256) {
        return troveManagers.length;
    }

    function deployNewInstance(IERC20 collateralToken, IPriceFeed priceFeed, DeploymentParams memory params)
        external
        onlyOwner
    {
        ITroveManager troveManagerClone =
            ITroveManager(address(troveManager).cloneDeterministic(bytes32(bytes20(address(collateralToken)))));
        troveManagers.push(troveManagerClone);

        ISortedTroves sortedTrovesClone =
            ISortedTroves(address(sortedTroves).cloneDeterministic(bytes32(bytes20(address(troveManagerClone)))));

        troveManagerClone.setConfig(sortedTrovesClone, collateralToken);
        sortedTrovesClone.setConfig(troveManagerClone);

        // verify that the oracle is correctly working
        troveManagerClone.fetchPrice();

        stabilityPool.enableCollateral(collateralToken);
        liquidationManager.enableTroveManager(troveManagerClone);
        debtToken.enableTroveManager(troveManagerClone);
        borrowerOperations.configureCollateral(troveManagerClone, collateralToken);

        troveManagerClone.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR
        );

        emit NewDeployment(collateralToken, priceFeed, troveManagerClone, sortedTrovesClone);
    }
}
