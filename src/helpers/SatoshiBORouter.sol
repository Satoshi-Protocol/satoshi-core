// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISatoshiBORouter} from "./interfaces/ISatoshiBORouter.sol";
import {IReferralManager} from "./interfaces/IReferralManager.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";

/**
 * @title Satoshi Borrower Operations Router
 *        Handle the native token and ERC20 for the borrower operations
 */
contract SatoshiBORouter is ISatoshiBORouter {
    using SafeERC20 for *;

    IDebtToken public immutable debtToken;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    IReferralManager public immutable referralManager;
    IWETH public immutable weth;

    constructor(
        IDebtToken _debtToken,
        IBorrowerOperations _borrowerOperationsProxy,
        IReferralManager _referralManager,
        IWETH _weth
    ) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (address(_borrowerOperationsProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_referralManager) == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();

        debtToken = _debtToken;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        referralManager = _referralManager;
        weth = _weth;
    }

    // account should call borrowerOperationsProxy.setDelegateApproval first
    // to approve this contract to call openTrove
    function openTrove(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        address _referrer
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiBORouter: Debt amount mismatch");
        _afterWithdrawDebt(msg.sender, _referrer, userDebtAmount, troveManager);
    }

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable
    {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.addColl(troveManager, msg.sender, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawColl(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint)
        external
    {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        borrowerOperationsProxy.withdrawColl(troveManager, msg.sender, _collWithdrawal, _upperHint, _lowerHint);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == _collWithdrawal, "SatoshiBORouter: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function withdrawDebt(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiBORouter: Debt amount mismatch");

        address _referrer = referralManager.getReferrer(msg.sender);
        _afterWithdrawDebt(msg.sender, _referrer, userDebtAmount, troveManager);
    }

    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external
    {
        _beforeRepayDebt(_debtAmount);

        borrowerOperationsProxy.repayDebt(troveManager, msg.sender, _debtAmount, _upperHint, _lowerHint);
    }

    function adjustTrove(
        ITroveManager troveManager,
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

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        // repay debt
        if (!_isDebtIncrease) {
            _beforeRepayDebt(_debtChange);
        }

        borrowerOperationsProxy.adjustTrove(
            troveManager,
            msg.sender,
            _maxFeePercentage,
            _collDeposit,
            _collWithdrawal,
            _debtChange,
            _isDebtIncrease,
            _upperHint,
            _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        // withdraw collateral
        _afterWithdrawColl(collateralToken, _collWithdrawal);

        // withdraw debt
        if (_isDebtIncrease) {
            require(
                debtTokenBalanceAfter - debtTokenBalanceBefore == _debtChange, "SatoshiBORouter: Debt amount mismatch"
            );

            _afterWithdrawDebt(msg.sender, referralManager.getReferrer(msg.sender), _debtChange, troveManager);
        }
    }

    function closeTrove(ITroveManager troveManager) external {
        (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(msg.sender);
        uint256 netDebtAmount = debtAmount - borrowerOperationsProxy.DEBT_GAS_COMPENSATION();
        _beforeRepayDebt(netDebtAmount);

        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        borrowerOperationsProxy.closeTrove(troveManager, msg.sender);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == collAmount, "SatoshiBORouter: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function _beforeAddColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            if (msg.value != collAmount) revert MsgValueMismatch(msg.value, collAmount);

            weth.deposit{value: collAmount}();
        } else {
            if (msg.value != 0) revert InvalidMsgValue(msg.value);
            collateralToken.safeTransferFrom(msg.sender, address(this), collAmount);
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
            collateralToken.safeTransfer(msg.sender, collAmount);
        }
    }

    function _beforeRepayDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.safeTransferFrom(msg.sender, address(this), debtAmount);
    }

    function _afterWithdrawDebt(address _borrower, address _referrer, uint256 debtAmount, ITroveManager troveManager)
        private
    {
        if (debtAmount == 0) return;

        debtToken.safeTransfer(msg.sender, debtAmount);

        // execute referral
        referralManager.executeReferral(_borrower, _referrer, debtAmount, troveManager);
    }

    receive() external payable {
        // to receive native token
    }
}
