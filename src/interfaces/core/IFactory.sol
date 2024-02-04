// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Upgradeable as IERC20} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {IStabilityPool} from "./IStabilityPool.sol";
import {IBorrowerOperations} from "./IBorrowerOperations.sol";
import {ILiquidationManager} from "./ILiquidationManager.sol";
import {ISortedTroves} from "./ISortedTroves.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {IPrismaCore} from "./IPrismaCore.sol";
import {IPriceFeed} from "../dependencies/IPriceFeed.sol";
import {IPrismaOwnable} from "../dependencies/IPrismaOwnable.sol";

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

interface IFactory is IPrismaOwnable {
    event NewDeployment(
        IERC20 collateral, IPriceFeed priceFeed, ITroveManager troveManager, ISortedTroves sortedTroves
    );

    function deployNewInstance(IERC20 collateral, IPriceFeed priceFeed, DeploymentParams calldata params) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function debtToken() external view returns (IDebtToken);

    function liquidationManager() external view returns (ILiquidationManager);

    function sortedTroves() external view returns (ISortedTroves);

    function stabilityPool() external view returns (IStabilityPool);

    function troveManagerCount() external view returns (uint256);

    function troveManager() external view returns (ITroveManager);

    function troveManagers(uint256) external view returns (ITroveManager);
}
