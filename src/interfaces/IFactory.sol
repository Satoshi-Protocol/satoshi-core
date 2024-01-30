// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";
import {IStabilityPool} from "../interfaces/IStabilityPool.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {ILiquidationManager} from "../interfaces/ILiquidationManager.sol";
import {ISortedTroves} from "../interfaces/ISortedTroves.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IPrismaCore} from "../interfaces/IPrismaCore.sol";
import {IPriceFeed} from "../interfaces/IPriceFeed.sol";

// commented values are suggested default parameters
struct DeploymentParams {
    uint256 minuteDecayFactor; // 999037758833783500  (half life of 12 hours)
    uint256 redemptionFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxRedemptionFee; // 1e18  (100%)
    uint256 borrowingFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxBorrowingFee; // 1e18 / 100 * 5  (5%)
    uint256 interestRateInBps; // 250 (2.5%)
    uint256 maxDebt; // 1e18 * 1000000000 (1 billion)
    uint256 MCR; // 11 * 1e17  (110%)
}

interface IFactory {
    event NewDeployment(
        IERC20 collateral, IPriceFeed priceFeed, ITroveManager troveManager, ISortedTroves sortedTroves
    );

    function deployNewInstance(
        IERC20 collateral,
        IPriceFeed priceFeed,
        ITroveManager customTroveManagerImpl,
        ISortedTroves customSortedTrovesImpl,
        DeploymentParams calldata params
    ) external;

    function setImplementations(ITroveManager _troveManagerImpl, ISortedTroves _sortedTrovesImpl) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function debtToken() external view returns (IDebtToken);

    function liquidationManager() external view returns (ILiquidationManager);

    function sortedTrovesImpl() external view returns (ISortedTroves);

    function stabilityPool() external view returns (IStabilityPool);

    function troveManagerCount() external view returns (uint256);

    function troveManagerImpl() external view returns (ITroveManager);

    function troveManagers(uint256) external view returns (ITroveManager);
}
