// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISatoshiPeriphery} from "./interfaces/ISatoshiPeriphery.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {ISupraOraclePull} from "../interfaces/dependencies/priceFeed/ISupraOraclePull.sol";

/**
 * @title Satoshi Borrower Operations Router
 *        Handle the native token and ERC20 for the borrower operations
 */
contract SatoshiPeriphery is ISatoshiPeriphery, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20Upgradeable for *;

    IDebtToken public immutable debtToken;
    IBorrowerOperations public immutable borrowerOperationsProxy;
    IWETH public immutable weth;

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
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
        _afterWithdrawDebt(userDebtAmount);
    }

    function openTroveWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(troveManager, _collAmount, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
        _afterWithdrawDebt(userDebtAmount);

        _refundGas();
    }

    function openTroveWithSupraPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes calldata _bytesProof
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _updateSupraPriceFeed(troveManager, _bytesProof);

        _beforeAddColl(collateralToken, _collAmount);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        borrowerOperationsProxy.openTrove(
            troveManager, msg.sender, _maxFeePercentage, _collAmount, _debtAmount, _upperHint, _lowerHint
        );

        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");
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

    function addCollWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _collAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(troveManager, _collAmount, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        _beforeAddColl(collateralToken, _collAmount);

        borrowerOperationsProxy.addColl(troveManager, msg.sender, _collAmount, _upperHint, _lowerHint);

        _refundGas();
    }

    function addCollWithSupraPriceUpdate(ITroveManager troveManager, uint256 _collAmount, address _upperHint, address _lowerHint, bytes calldata _bytesProof)
        external
        payable
    {
        IERC20 collateralToken = troveManager.collateralToken();

        _updateSupraPriceFeed(troveManager, _bytesProof);

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
        require(userCollAmount == _collWithdrawal, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function withdrawCollWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable nonReentrant {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        _checkEnoughValue(troveManager, 0, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        borrowerOperationsProxy.withdrawColl(troveManager, msg.sender, _collWithdrawal, _upperHint, _lowerHint);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == _collWithdrawal, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);

        _refundGas();
    }

    function withdrawCollWithSupraPriceUpdate(ITroveManager troveManager, uint256 _collWithdrawal, address _upperHint, address _lowerHint, bytes calldata _bytesProof)
        external
    {
        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        _updateSupraPriceFeed(troveManager, _bytesProof);

        borrowerOperationsProxy.withdrawColl(troveManager, msg.sender, _collWithdrawal, _upperHint, _lowerHint);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == _collWithdrawal, "SatoshiPeriphery: Collateral amount mismatch");
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
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount);
    }

    function withdrawDebtWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable nonReentrant {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        _checkEnoughValue(troveManager, 0, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount);

        _refundGas();
    }

    function withdrawDebtWithSupraPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes calldata _bytesProof
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));

        _updateSupraPriceFeed(troveManager, _bytesProof);

        borrowerOperationsProxy.withdrawDebt(
            troveManager, msg.sender, _maxFeePercentage, _debtAmount, _upperHint, _lowerHint
        );
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        require(userDebtAmount == _debtAmount, "SatoshiPeriphery: Debt amount mismatch");

        _afterWithdrawDebt(userDebtAmount);
    }

    function repayDebt(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint)
        external
    {
        _beforeRepayDebt(_debtAmount);

        borrowerOperationsProxy.repayDebt(troveManager, msg.sender, _debtAmount, _upperHint, _lowerHint);
    }

    function repayDebtWithPythPriceUpdate(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint,
        bytes[] calldata priceUpdateData
    ) external payable {
        _checkEnoughValue(troveManager, 0, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        _beforeRepayDebt(_debtAmount);

        borrowerOperationsProxy.repayDebt(troveManager, msg.sender, _debtAmount, _upperHint, _lowerHint);

        _refundGas();
    }

    function repayDebtWithSupraPriceUpdate(ITroveManager troveManager, uint256 _debtAmount, address _upperHint, address _lowerHint, bytes calldata _bytesProof)
        external
    {
        _updateSupraPriceFeed(troveManager, _bytesProof);
        
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
                debtTokenBalanceAfter - debtTokenBalanceBefore == _debtChange, "SatoshiPeriphery: Debt amount mismatch"
            );

            _afterWithdrawDebt(_debtChange);
        }
    }

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
    ) external payable nonReentrant {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(troveManager, _collDeposit, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

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
                debtTokenBalanceAfter - debtTokenBalanceBefore == _debtChange, "SatoshiPeriphery: Debt amount mismatch"
            );

            _afterWithdrawDebt(_debtChange);
        }

        _refundGas();
    }

    function adjustTroveWithSupraPriceUpdate(
        ITroveManager troveManager,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint,
        bytes calldata _bytesProof
    ) external payable {
        if (_collDeposit != 0 && _collWithdrawal != 0) revert CannotWithdrawAndAddColl();

        IERC20 collateralToken = troveManager.collateralToken();

        _updateSupraPriceFeed(troveManager, _bytesProof);

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
                debtTokenBalanceAfter - debtTokenBalanceBefore == _debtChange, "SatoshiPeriphery: Debt amount mismatch"
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
        require(userCollAmount == collAmount, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function closeTroveWithPythPriceUpdate(ITroveManager troveManager, bytes[] calldata priceUpdateData)
        external
        payable
    {
        (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(msg.sender);
        uint256 netDebtAmount = debtAmount - borrowerOperationsProxy.DEBT_GAS_COMPENSATION();

        _checkEnoughValue(troveManager, 0, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        _beforeRepayDebt(netDebtAmount);

        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        borrowerOperationsProxy.closeTrove(troveManager, msg.sender);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == collAmount, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);

        _refundGas();
    }

    function closeTroveWithSupraPriceUpdate(ITroveManager troveManager, bytes calldata _bytesProof) external {
        (uint256 collAmount, uint256 debtAmount) = troveManager.getTroveCollAndDebt(msg.sender);
        uint256 netDebtAmount = debtAmount - borrowerOperationsProxy.DEBT_GAS_COMPENSATION();
        
        _updateSupraPriceFeed(troveManager, _bytesProof);

        _beforeRepayDebt(netDebtAmount);

        IERC20 collateralToken = troveManager.collateralToken();
        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        borrowerOperationsProxy.closeTrove(troveManager, msg.sender);

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        require(userCollAmount == collAmount, "SatoshiPeriphery: Collateral amount mismatch");
        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function redeemCollateral(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external {
        IERC20 collateralToken = troveManager.collateralToken();

        _beforeRepayDebt(_debtAmount);

        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        troveManager.redeemCollateral(
            _debtAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;

        _afterWithdrawColl(collateralToken, userCollAmount);
    }

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
    ) external payable nonReentrant {
        IERC20 collateralToken = troveManager.collateralToken();

        _checkEnoughValue(troveManager, 0, priceUpdateData);

        _updatePythPriceFeed(troveManager, priceUpdateData);

        _beforeRepayDebt(_debtAmount);

        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        troveManager.redeemCollateral(
            _debtAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;

        _afterWithdrawColl(collateralToken, userCollAmount);

        _refundGas();
    }

    function redeemCollateralWithSupraPriceUpdate(
        ITroveManager troveManager,
        uint256 _debtAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage,
        bytes calldata _bytesProof
    ) external {
        IERC20 collateralToken = troveManager.collateralToken();

        _updateSupraPriceFeed(troveManager, _bytesProof);

        _beforeRepayDebt(_debtAmount);

        uint256 collTokenBalanceBefore = collateralToken.balanceOf(address(this));

        troveManager.redeemCollateral(
            _debtAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );

        uint256 collTokenBalanceAfter = collateralToken.balanceOf(address(this));
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;

        _afterWithdrawColl(collateralToken, userCollAmount);
    }

    function liquidateTroves(
        ILiquidationManager liquidationManager,
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR
    ) external {
        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceBefore = troveManager.collateralToken().balanceOf(address(this));
        liquidationManager.liquidateTroves(troveManager, maxTrovesToLiquidate, maxICR);
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceAfter = troveManager.collateralToken().balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        _afterWithdrawDebt(userDebtAmount);
        _afterWithdrawColl(troveManager.collateralToken(), userCollAmount);
    }

    function liquidateTrovesWithPythPriceUpdate(
        ILiquidationManager liquidationManager,
        ITroveManager troveManager,
        uint256 maxTrovesToLiquidate,
        uint256 maxICR,
        bytes[] calldata priceUpdateData
    ) external payable {
        _checkEnoughValue(troveManager, 0, priceUpdateData);
        _updatePythPriceFeed(troveManager, priceUpdateData);

        uint256 debtTokenBalanceBefore = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceBefore = troveManager.collateralToken().balanceOf(address(this));
        liquidationManager.liquidateTroves(troveManager, maxTrovesToLiquidate, maxICR);
        uint256 debtTokenBalanceAfter = debtToken.balanceOf(address(this));
        uint256 collTokenBalanceAfter = troveManager.collateralToken().balanceOf(address(this));
        uint256 userDebtAmount = debtTokenBalanceAfter - debtTokenBalanceBefore;
        uint256 userCollAmount = collTokenBalanceAfter - collTokenBalanceBefore;
        _afterWithdrawDebt(userDebtAmount);
        _afterWithdrawColl(troveManager.collateralToken(), userCollAmount);
    }

    function _beforeAddColl(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            if (msg.value < collAmount) revert MsgValueMismatch(msg.value, collAmount);

            weth.deposit{value: collAmount}();
        } else {
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

    function _checkEnoughValue(ITroveManager troveManager, uint256 _collAmount, bytes[] calldata priceUpdateData)
        internal
    {
        IERC20 collateralToken = troveManager.collateralToken();
        (IPriceFeed priceFeed,) = troveManager.priceFeedAggregator().oracleRecords(troveManager.collateralToken());
        IPyth pyth = IPyth(priceFeed.source());
        uint256 fee = pyth.getUpdateFee(priceUpdateData);

        if (address(collateralToken) == address(weth)) {
            if (msg.value < _collAmount + fee) revert InsufficientMsgValue(msg.value, _collAmount + fee);
        } else {
            if (msg.value < fee) revert InsufficientMsgValue(msg.value, fee);
        }
    }

    function _refundGas() internal {
        if (address(this).balance != 0) {
            (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
            if (!success) revert RefundFailed();
        }
    }

    function _updatePythPriceFeed(ITroveManager troveManager, bytes[] calldata priceUpdateData) internal {
        (IPriceFeed priceFeed,) = troveManager.priceFeedAggregator().oracleRecords(troveManager.collateralToken());
        IPyth pyth = IPyth(priceFeed.source());
        uint256 fee = pyth.getUpdateFee(priceUpdateData);
        pyth.updatePriceFeeds{value: fee}(priceUpdateData);
    }

    function _updateSupraPriceFeed(ITroveManager troveManager, bytes calldata _bytesProof) internal {
        (IPriceFeed priceFeed,) = troveManager.priceFeedAggregator().oracleRecords(troveManager.collateralToken());
        ISupraOraclePull supra_pull = ISupraOraclePull(priceFeed.source());
        supra_pull.verifyOracleProof(_bytesProof);
    }

    receive() external payable {
        // to receive native token
    }
}
