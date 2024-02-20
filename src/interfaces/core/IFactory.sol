// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {IDebtToken} from "./IDebtToken.sol";
import {IStabilityPool} from "./IStabilityPool.sol";
import {IBorrowerOperations} from "./IBorrowerOperations.sol";
import {ILiquidationManager} from "./ILiquidationManager.sol";
import {ISortedTroves} from "./ISortedTroves.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";
import {IPriceFeed} from "../dependencies/IPriceFeed.sol";
import {IPriceFeedAggregator} from "./IPriceFeedAggregator.sol";
import {IGasPool} from "./IGasPool.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";

// commented values are suggested default parameters
struct DeploymentParams {
    uint256 minuteDecayFactor; // 999037758833783500  (half life of 12 hours)
    uint256 redemptionFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxRedemptionFee; // 1e18  (100%)
    uint256 borrowingFeeFloor; // 1e18 / 1000 * 5  (0.5%)
    uint256 maxBorrowingFee; // 1e18 / 100 * 5  (5%)
    uint256 interestRateInBps; // 450 (4.5%)
    uint256 maxDebt; // 1e18 * 1000000000 (1 billion)
    uint256 MCR; // 11 * 1e17  (110%)
}

interface IFactory is ISatoshiOwnable {
    event NewDeployment(
        IERC20 indexed collateral, IPriceFeed priceFeed, ITroveManager troveManager, ISortedTroves sortedTroves
    );

    function deployNewInstance(IERC20 collateralToken, IPriceFeed priceFeed, DeploymentParams memory params) external;

    function satoshiCore() external view returns (ISatoshiCore);

    function debtToken() external view returns (IDebtToken);

    function gasPool() external view returns (IGasPool);

    function priceFeedAggregatorProxy() external view returns (IPriceFeedAggregator);

    function borrowerOperationsProxy() external view returns (IBorrowerOperations);

    function liquidationManagerProxy() external view returns (ILiquidationManager);

    function stabilityPoolProxy() external view returns (IStabilityPool);

    function sortedTrovesBeacon() external view returns (IBeacon);

    function troveManagerBeacon() external view returns (IBeacon);

    function gasCompensation() external view returns (uint256);

    function troveManagerCount() external view returns (uint256);

    function troveManagers(uint256) external view returns (ITroveManager);
}
