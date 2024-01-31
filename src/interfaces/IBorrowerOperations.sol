// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "../interfaces/ITroveManager.sol";
import {IPrismaBase} from "../interfaces/IPrismaBase.sol";
import {IPrismaOwnable} from "../interfaces/IPrismaOwnable.sol";
import {IDelegatedOps} from "../interfaces/IDelegatedOps.sol";
import {IFactory} from "../interfaces/IFactory.sol";
import {IDebtToken} from "../interfaces/IDebtToken.sol";

enum BorrowerOperation {
    openTrove,
    closeTrove,
    adjustTrove
}

struct Balances {
    uint256[] collaterals;
    uint256[] debts;
    uint256[] prices;
}

struct TroveManagerData {
    IERC20 collateralToken;
    uint16 index;
}

interface IBorrowerOperations is IPrismaOwnable, IPrismaBase, IDelegatedOps {
    event BorrowingFeePaid(address indexed borrower, IERC20 indexed collateralToken, uint256 amount);
    event CollateralConfigured(ITroveManager troveManager, IERC20 indexed collateralToken);
    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveManagerRemoved(ITroveManager indexed troveManager);
    event TroveUpdated(address indexed _borrower, uint256 _debt, uint256 _coll, uint256 stake, uint8 operation);

    /// @notice Function to add collateral to a trove
    /// @param _troveManager trove manager contract
    /// @param _account address of the borrower
    /// @param _collateralAmount amount of collateral to add
    /// @param _upperHint upper hint
    /// @param _lowerHint lower hint
    function addColl(
        ITroveManager _troveManager,
        address _account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    /// @notice Function to adjust a trove
    /// @param _troveManager trove manager contract
    /// @param _account address of the borrower
    /// @param _maxFeePercentage max fee percentage
    /// @param _collDeposit amount of collateral to add
    /// @param _collWithdrawal amount of collateral to withdraw
    /// @param _debtChange amount of debt to change
    /// @param _isDebtIncrease flag to indicate if debt is increased
    /// @param _upperHint upper hint
    /// @param _lowerHint lower hint
    function adjustTrove(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collDeposit,
        uint256 _collWithdrawal,
        uint256 _debtChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;

    /// @notice Function to close a trove
    /// @param _troveManager trove manager contract
    /// @param _account address of the borrower
    function closeTrove(ITroveManager _troveManager, address _account) external;

    /// @notice Function to configure collateral
    /// @param _troveManager trove manager contract
    /// @param _collateralToken address of the collateral token
    function configureCollateral(ITroveManager _troveManager, IERC20 _collateralToken) external;

    /// @notice Get total collateral and debt balances for all active collaterals, as well as
    ///         the current collateral prices
    /// @dev Not a view because fetching from the oracle is state changing.
    ///      Can still be accessed as a view from within the UX.
    /// @return balances Balances struct
    function fetchBalances() external returns (Balances memory balances);

    function getGlobalSystemBalances() external returns (uint256 totalPricedCollateral, uint256 totalDebt);

    function getTCR() external returns (uint256 globalTotalCollateralRatio);

    function openTrove(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _collateralAmount,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function removeTroveManager(ITroveManager _troveManager) external;

    function repayDebt(
        ITroveManager _troveManager,
        address _account,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function setMinNetDebt(uint256 _minNetDebt) external;

    function withdrawColl(
        ITroveManager _troveManager,
        address _account,
        uint256 _collWithdrawal,
        address _upperHint,
        address _lowerHint
    ) external;

    function withdrawDebt(
        ITroveManager _troveManager,
        address _account,
        uint256 _maxFeePercentage,
        uint256 _debtAmount,
        address _upperHint,
        address _lowerHint
    ) external;

    function checkRecoveryMode(uint256 TCR) external pure returns (bool);

    function debtToken() external view returns (IDebtToken);

    function factory() external view returns (IFactory);

    function getCompositeDebt(uint256 _debt) external view returns (uint256);

    function minNetDebt() external view returns (uint256);

    function troveManagersData(ITroveManager _troveManager)
        external
        view
        returns (IERC20 collateralToken, uint16 index);
}
