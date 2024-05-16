// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "./ISatoshiCore.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {ISatoshiBase} from "../dependencies/ISatoshiBase.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {IBorrowerOperations} from "./IBorrowerOperations.sol";
import {IStabilityPool} from "./IStabilityPool.sol";
import {IFactory} from "./IFactory.sol";

struct TroveManagerValues {
    uint256 price;
    uint256 MCR;
    bool sunsetting;
}

struct LiquidationValues {
    uint256 entireTroveDebt;
    uint256 entireTroveColl;
    uint256 collGasCompensation;
    uint256 debtGasCompensation;
    uint256 debtToOffset;
    uint256 collToSendToSP;
    uint256 debtToRedistribute;
    uint256 collToRedistribute;
    uint256 collSurplus;
}

struct LiquidationTotals {
    uint256 totalCollInSequence;
    uint256 totalDebtInSequence;
    uint256 totalCollGasCompensation;
    uint256 totalDebtGasCompensation;
    uint256 totalDebtToOffset;
    uint256 totalCollToSendToSP;
    uint256 totalDebtToRedistribute;
    uint256 totalCollToRedistribute;
    uint256 totalCollSurplus;
}

interface ILiquidationManager is ISatoshiOwnable, ISatoshiBase {
    event Liquidation(
        uint256 _liquidatedDebt, uint256 _liquidatedColl, uint256 _collGasCompensation, uint256 _debtGasCompensation
    );
    event LiquidationTroves(
        address indexed _troveManager,
        uint256 _liquidatedDebt,
        uint256 _liquidatedColl,
        uint256 _collGasCompensation,
        uint256 _debtGasCompensation
    );
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);

    function initialize(
        ISatoshiCore _satoshiCore,
        IStabilityPool _stabilityPool,
        IBorrowerOperations _borrowerOperations,
        IFactory _factory,
        uint256 _gasCompensation
    ) external;

    function batchLiquidateTroves(ITroveManager troveManager, address[] calldata _troveArray) external;

    function enableTroveManager(ITroveManager _troveManager) external;

    function liquidate(ITroveManager troveManager, address borrower) external;

    function liquidateTroves(ITroveManager troveManager, uint256 maxTrovesToLiquidate, uint256 maxICR) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function factory() external view returns (IFactory);

    function stabilityPool() external view returns (IStabilityPool);
}
