// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPrismaBase} from "../interfaces/IPrismaBase.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IBorrowerOperations} from "../interfaces/IBorrowerOperations.sol";
import {IStabilityPool} from "../interfaces/IStabilityPool.sol";
import {IFactory} from "../interfaces/IFactory.sol";

interface ILiquidationManager is IPrismaBase {
    event Liquidation(
        uint256 _liquidatedDebt, uint256 _liquidatedColl, uint256 _collGasCompensation, uint256 _debtGasCompensation
    );
    event TroveLiquidated(address indexed _borrower, uint256 _debt, uint256 _coll, uint8 _operation);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint256 _stake, uint8 _operation);

    function batchLiquidateTroves(ITroveManager troveManager, address[] calldata _troveArray) external;

    function enableTroveManager(ITroveManager _troveManager) external;

    function liquidate(ITroveManager troveManager, address borrower) external;

    function liquidateTroves(ITroveManager troveManager, uint256 maxTrovesToLiquidate, uint256 maxICR) external;

    function borrowerOperations() external view returns (IBorrowerOperations);

    function factory() external view returns (IFactory);

    function stabilityPool() external view returns (IStabilityPool);
}
