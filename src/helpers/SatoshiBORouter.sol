// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISatoshiBORouter} from "./interfaces/ISatoshiBORouter.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";

/**
 * @title Satoshi Borrower Operations Router
 *        Handle the native token and ERC20 for the borrower operations
 */
contract SatoshiBORouter is ISatoshiBORouter {
    using SafeERC20 for IERC20;
    using SafeERC20Upgradeable for *;

    IDebtToken public immutable debtToken;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    IWETH public immutable weth;
    IPyth public immutable pyth;

    constructor(IDebtToken _debtToken, IBorrowerOperations _borrowerOperationsProxy, IWETH _weth, IPyth _pyth) {
        if (address(_debtToken) == address(0)) revert InvalidZeroAddress();
        if (address(_borrowerOperationsProxy) == address(0)) revert InvalidZeroAddress();
        if (address(_weth) == address(0)) revert InvalidZeroAddress();
        if (address(_pyth) == address(0)) revert InvalidZeroAddress();

        debtToken = _debtToken;
        borrowerOperationsProxy = _borrowerOperationsProxy;
        weth = _weth;
        pyth = _pyth;
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
        bytes[] calldata priceUpdateData
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(collateralToken, _collAmount, priceUpdateData);

        _updatePythPrice(priceUpdateData);

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiBORouter: Debt amount mismatch");
        _afterWithdrawDebt(userDebtAmount);
    }

    function addColl(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint)
        external
        payable
    {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.addColl(troveManager, msg.sender, _collAmount, _upperHint, _lowerHint);
    }

    function withdrawColl(
        ITroveManager troveManager,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        _checkEnoughValue(collateralToken, 0, priceUpdateData);

        _updatePythPrice(priceUpdateData);

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
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        IERC20 collateralToken = troveManager.collateralToken();
        _checkEnoughValue(collateralToken, 0, priceUpdateData);

        _updatePythPrice(priceUpdateData);

        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiBORouter: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount);
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
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(collateralToken, _collDeposit, priceUpdateData);

        _updatePythPrice(priceUpdateData);

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

            _afterWithdrawDebt(_debtChange);
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
            if (msg.value > collAmount) revert MsgValueMismatch(msg.value, collAmount);

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

    function _afterWithdrawDebt(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.safeTransfer(msg.sender, debtAmount);
    }

    function _updatePythPrice(bytes[] calldata priceUpdateData) internal {
        // Update the prices to the latest available values and pay the required fee for it. The `priceUpdateData` data
        // should be retrieved from our off-chain Price Service API using the `pyth-evm-js` package.
        // See section "How Pyth Works on EVM Chains" below for more information.
        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(priceUpdateData);
    }

    function _checkEnoughValue(IERC20 collateralToken, uint256 _collAmount, bytes[] calldata priceUpdateData)
        internal
    {
        uint256 fee = pyth.getUpdateFee(priceUpdateData);

        if (address(collateralToken) == address(weth)) {
            if (msg.value < _collAmount + fee) revert InsufficientMsgValue(msg.value, _collAmount + fee);
        } else {
            if (msg.value < fee) revert InsufficientMsgValue(msg.value, fee);
        }
    }

    receive() external payable {
        // to receive native token
    }
}
