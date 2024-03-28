// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IDebtToken} from "../../interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";
import {IReferralManager} from "./IReferralManager.sol";
import {IWETH} from "./IWETH.sol";

interface ISatoshiBORouter {
    error MsgValueMismatch(uint256 msgValue, uint256 collAmount);
    error InvalidMsgValue(uint256 msgValue);
    error NativeTokenTransferFailed();
    error CannotWithdrawAndAddColl();
    error InvalidZeroAddress();

    function debtToken() external view returns (IDebtToken);

    function borrowerOperationsProxy() external view returns (IBorrowerOperations);

    function referralManager() external view returns (IReferralManager);

    function weth() external view returns (IWETH);

    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        address _referrer
    ) external payable;

    function addColl(
        ITroveManager troveManager,
        uint256 _collAmount,
        address _upperHint,
        address _lowerHint
    ) external payable;

    function withdrawColl(
        ITroveManager troveManager,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function repayDebt(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

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

    function closeTrove(ITroveManager troveManager) external;
}
