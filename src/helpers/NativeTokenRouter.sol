// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";

contract NativeTokenRouter {
    IDebtToken public immutable debtToken;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    ITroveManager public immutable wrappedNativeTokenTroveManagerBeaconProxy;
    IWETH public immutable weth;

    error NotWrappedNativeToken(address collateralToken, address weth);
    error InvalidMsgValue(uint256 msgValue, uint256 collAmount);
    error NativeTokenTransferFailed();
    error CannotWithdrawAndAddColl();
    error InvalidZeroAddress();

    constructor(
        IDebtToken _debtToken,
        IBorrowerOperations _borrowerOperationsProxy,
        ITroveManager _wrappedNativeTokenTroveManagerBeaconProxy,
        IWETH _weth
    ) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (address(_borrowerOperationsProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_wrappedNativeTokenTroveManagerBeaconProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();

        (IERC20 collateralToken,) =
            _borrowerOperationsProxy.troveManagersData(_wrappedNativeTokenTroveManagerBeaconProxy);
        if (address(collateralToken) != address(_weth)) {
            revert NotWrappedNativeToken(address(collateralToken), address(_weth));
        }

        debtToken = _debtToken;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        wrappedNativeTokenTroveManagerBeaconProxy = _wrappedNativeTokenTroveManagerBeaconProxy;
        weth = _weth;
    }

    // account should call borrowerOperationsProxy.setDelegateApproval first
    // to approve this contract to call openTrove
    function openTroveByNativeToken(
        address account,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        if (msg.value != _collAmount) revert InvalidMsgValue(msg.value, _collAmount);

        weth.deposit{value: _collAmount}();
        weth.approve(address(borrowerOperationsProxy), _collAmount);

        borrowerOperationsProxy.openTrove(
            wrappedNativeTokenTroveManagerBeaconProxy,
            account,
            _maxFeePercentage,
            _collAmount,
            _debtAmount,
            _upperHint,
            _lowerHint
        );

        if (_debtAmount > 0) {
            debtToken.transfer(account, _debtAmount);
        }
    }

    function addCollByNativeToken(address account, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable
    {
        if (msg.value != _collAmount) revert InvalidMsgValue(msg.value, _collAmount);

        weth.deposit{value: _collAmount}();
        weth.approve(address(borrowerOperationsProxy), _collAmount);

        borrowerOperationsProxy.addColl(
            wrappedNativeTokenTroveManagerBeaconProxy, account, _collAmount, _upperHint, _lowerHint
        );
    }

    function withdrawCollByNativeToken(address account, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external
    {
        borrowerOperationsProxy.withdrawColl(
            wrappedNativeTokenTroveManagerBeaconProxy, account, _collWithdrawal, _upperHint, _lowerHint
        );

        weth.withdraw(_collWithdrawal);
        (bool success,) = payable(msg.sender).call{value: _collWithdrawal}("");
        if (!success) revert NativeTokenTransferFailed();
    }

    function adjustTroveByNativeToken(
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

        if (_collDeposit > 0) {
            if (msg.value != _collDeposit) revert InvalidMsgValue(msg.value, _collDeposit);

            weth.deposit{value: _collDeposit}();
            weth.approve(address(borrowerOperationsProxy), _collDeposit);
        }

        if(!_isDebtIncrease && _debtChange > 0) {
            debtToken.transferFrom(msg.sender, address(this), _debtChange);
        }

        borrowerOperationsProxy.adjustTrove(
            wrappedNativeTokenTroveManagerBeaconProxy,
            account,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );

        if (_collWithdrawal > 0) {
            weth.withdraw(_collWithdrawal);
            (bool success,) = payable(msg.sender).call{value: _collWithdrawal}("");
            if (!success) revert NativeTokenTransferFailed();
        }

        if(_isDebtIncrease && _debtChange > 0) {
            debtToken.transfer(account, _debtChange);
        }
    }

    function closeTroveByNativeToken(address account) external {
        (uint256 collAmount, uint256 debtAmount) =
            wrappedNativeTokenTroveManagerBeaconProxy.getTroveCollAndDebt(account);

        if (debtAmount > 0) {
            debtToken.transferFrom(msg.sender, address(this), debtAmount - borrowerOperationsProxy.DEBT_GAS_COMPENSATION());
        }

        borrowerOperationsProxy.closeTrove(wrappedNativeTokenTroveManagerBeaconProxy, account);

        if (collAmount > 0) {
            weth.withdraw(collAmount);
            (bool success,) = payable(msg.sender).call{value: collAmount}("");
            if (!success) revert NativeTokenTransferFailed();
        }
    }
}
