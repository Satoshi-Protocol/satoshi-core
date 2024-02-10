// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISatoshiBORouter} from "./interfaces/ISatoshiBORouter.sol";

///NOTE: This contract is to handle the native token and ERC20 for the borrower operations
contract SatoshiBORouter is ISatoshiBORouter {
    IDebtToken public immutable debtToken;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    IWETH public immutable weth;

    error MsgValueMismatch(uint256 msgValue, uint256 collAmount);
    error InvalidMsgValue(uint256 msgValue);
    error NativeTokenTransferFailed();
    error CannotWithdrawAndAddColl();
    error InvalidZeroAddress();

    constructor(IDebtToken _debtToken, IBorrowerOperations _borrowerOperationsProxy, IWETH _weth) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (address(_borrowerOperationsProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();

        debtToken = _debtToken;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        weth = _weth;
    }

    // account should call borrowerOperationsProxy.setDelegateApproval first
    // to approve this contract to call openTrove
    function openTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.openTrove(
            troveManager, account, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        _afterWithdrawDebt(_debtAmount);
    }

    function addColl(
        ITroveManager troveManager,
        address account,
        uint256 _collAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.addColl(troveManager, account, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawColl(
        ITroveManager troveManager,
        address account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperationsProxy.withdrawColl(troveManager, account, _collWithdrawal, _upperHint, _lowerHint);

        IERC20 collateralToken = troveManager.collateralToken();

        _afterWithdrawColl(collateralToken, _collWithdrawal);
    }

    function withdrawDebt(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        borrowerOperationsProxy.withdrawDebt(
            troveManager, account, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );

        _afterWithdrawDebt(_debtAmount);
    }

    function repayDebt(
        ITroveManager troveManager,
        address account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        _beforeRepayDebt(_debtAmount);

        borrowerOperationsProxy.repayDebt(troveManager, account, _debtAmount, _upperHint, _lowerHint);
    }

    function adjustTrove(
        ITroveManager troveManager,
        address account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external payable {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();

        // add collateral
        _beforeAddColl(collateralToken, _collDeposit);

        // repay debt
        if (!_isDebtIncrease) {
            _beforeRepayDebt(_debtChange);
        }

        borrowerOperationsProxy.adjustTrove(
            troveManager,
            account,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );

        // withdraw collateral
        _afterWithdrawColl(collateralToken, _collWithdrawal);

        // withdraw debt
        if (_isDebtIncrease) {
            _afterWithdrawDebt(_debtChange);
        }
    }

    function closeTrove(ITroveManager troveManager, address account) external {
        (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(account);

        _beforeRepayDebt(debtAmount);

        borrowerOperationsProxy.closeTrove(troveManager, account);

        IERC20 collateralToken = troveManager.collateralToken();

        _afterWithdrawColl(collateralToken, collAmount);
    }

    function _beforeAddColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            if (msg.value != collAmount) revert MsgValueMismatch(msg.value, collAmount);

            weth.deposit{value: collAmount}();
        } else {
            if (msg.value != 0) revert InvalidMsgValue(msg.value);
            collateralToken.transferFrom(msg.sender, address(this), collAmount);
        }

        collateralToken.approve(address(borrowerOperationsProxy), collAmount);
    }

    function _afterWithdrawColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            weth.withdraw(collAmount);
            (bool success,) = payable(msg.sender).call{value: collAmount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            collateralToken.transfer(msg.sender, collAmount);
        }
    }

    function _beforeRepayDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.transferFrom(msg.sender, address(this), debtAmount);
    }

    function _afterWithdrawDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.transfer(msg.sender, debtAmount);
    }
}
