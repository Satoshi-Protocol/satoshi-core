// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IDebtToken} from "../../interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";
import {IWETH} from "./IWETH.sol";
import {ILiquidationManager} from "../../interfaces/core/ILiquidationManager.sol";

interface ISatoshiPeriphery {
    error MsgValueMismatch(uint256 msgValue, uint256 collAmount);
    error InvalidMsgValue(uint256 msgValue);
    error NativeTokenTransferFailed();
    error CannotWithdrawAndAddColl();
    error InvalidZeroAddress();
    error RefundFailed();
    error InsufficientMsgValue(uint256 msgValue, uint256 requiredValue);

    function debtToken() external view returns (IDebtToken);

    function borrowerOperationsProxy() external view returns (IBorrowerOperations);

    function weth() external view returns (IWETH);

    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function openTroveWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable;

    function addCollWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _collAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function withdrawColl(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external;

    function withdrawCollWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebtWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external;

    function repayDebtWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function adjustTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function adjustTroveWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable;

    function closeTrove(ITroveManager troveManager) external;

    function closeTroveWithPythPriceUpdate(ITroveManager troveManager, bytes[] calldata priceUpdateData)
        external
        payable;

    function redeemCollateral(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external;

    function redeemCollateralWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage,
        bytes[] calldata priceUpdateData
    ) external payable;

    function liquidateTroves(
        ILiquidationManager liquidationManager,
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR
    ) external;

    function liquidateTrovesWithPythPriceUpdate(
        ILiquidationManager liquidationManager,
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR,
        bytes[] calldata priceUpdateData
    ) external payable;
}
