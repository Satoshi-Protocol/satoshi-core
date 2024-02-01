// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PrismaOwnable} from "../dependencies/PrismaOwnable.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {ISortedTroves} from "../interfaces/ISortedTroves.sol";
import {IStabilityPool} from "../interfaces/IStabilityPool.sol";
import {ILiquidationManager} from "../interfaces/ILiquidationManager.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";
import {IPrismaCore} from "../interfaces/IPrismaCore.sol";
import {DeploymentParams, IFactory} from "../interfaces/IFactory.sol";

/**
 * @title Prisma Trove Factory
 *     @notice Deploys cloned pairs of `TroveManager` and `SortedTroves` in order to
 *             add new collateral types within the system.
 */
contract Factory is IFactory, PrismaOwnable {
    using Clones for address;

    // fixed single-deployment contracts
    IDebtToken public immutable debtToken;
    IStabilityPool public immutable stabilityPool;
    ILiquidationManager public immutable liquidationManager;
    IBorrowerOperations public immutable borrowerOperations;

    // implementation contracts, redeployed each time via clone proxy
    ISortedTroves public sortedTrovesImpl;
    ITroveManager public troveManagerImpl;
    ITroveManager[] public troveManagers;

    constructor(
        IPrismaCore _prismaCore,
        IDebtToken _debtToken,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        ISortedTroves _sortedTroves,
        ITroveManager _troveManager,
        ILiquidationManager _liquidationManager
    ) PrismaOwnable(_prismaCore) {
        debtToken = IDebtToken(_debtToken);
        stabilityPool = IStabilityPool(_stabilityPool);
        borrowerOperations = IBorrowerOperations(_borrowerOperations);
        sortedTrovesImpl = ISortedTroves(_sortedTroves);
        troveManagerImpl = ITroveManager(_troveManager);
        liquidationManager = ILiquidationManager(_liquidationManager);
    }

    function troveManagerCount() external view returns (uint256) {
        return troveManagers.length;
    }

    /**
     * @notice Deploy new instances of `TroveManager` and `SortedTroves`, adding
     *             a new collateral type to the system.
     *     @dev * When using the default `PriceFeed`, ensure it is configured correctly
     *            prior to calling this function.
     * After calling this function, the owner should also call `Vault.registerReceiver`
     *            to enable PRISMA emissions on the newly deployed `TroveManager`
     *     @param collateralToken Collateral token to use in new deployment
     *     @param priceFeed Custom `PriceFeed` deployment. Leave as `address(0)` to use the default.
     *     @param customTroveManagerImpl Custom `TroveManager` implementation to clone from.
     *                                   Leave as `address(0)` to use the default.
     *     @param customSortedTrovesImpl Custom `SortedTroves` implementation to clone from.
     *                                   Leave as `address(0)` to use the default.
     *     @param params Struct of initial parameters to be set on the new trove manager
     */
    function deployNewInstance(
        IERC20 collateralToken,
        IPriceFeed priceFeed,
        ITroveManager customTroveManagerImpl,
        ISortedTroves customSortedTrovesImpl,
        DeploymentParams memory params
    ) external onlyOwner {
        address implementation =
            address(customTroveManagerImpl) == address(0) ? address(troveManagerImpl) : address(customTroveManagerImpl);
        ITroveManager troveManager =
            ITroveManager(implementation.cloneDeterministic(bytes32(bytes20(address(collateralToken)))));
        troveManagers.push(troveManager);

        implementation =
            address(customSortedTrovesImpl) == address(0) ? address(sortedTrovesImpl) : address(customSortedTrovesImpl);
        ISortedTroves sortedTroves =
            ISortedTroves(implementation.cloneDeterministic(bytes32(bytes20(address(troveManager)))));

        troveManager.setAddresses(address(priceFeed), address(sortedTroves), address(collateralToken));
        sortedTroves.setAddresses(address(troveManager));

        // verify that the oracle is correctly working
        ITroveManager(troveManager).fetchPrice();

        stabilityPool.enableCollateral(collateralToken);
        liquidationManager.enableTroveManager(troveManager);
        debtToken.enableTroveManager(troveManager);
        borrowerOperations.configureCollateral(troveManager, collateralToken);

        troveManager.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR
        );

        emit NewDeployment(collateralToken, priceFeed, troveManager, sortedTroves);
    }

    function setImplementations(ITroveManager _troveManagerImpl, ISortedTroves _sortedTrovesImpl) external onlyOwner {
        troveManagerImpl = _troveManagerImpl;
        sortedTrovesImpl = _sortedTrovesImpl;
    }
}
