// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";
import {ISatoshiBase} from "../dependencies/ISatoshiBase.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IDelegatedOps} from "../dependencies/IDelegatedOps.sol";
import {IFactory} from "./IFactory.sol";
import {IDebtToken} from "./IDebtToken.sol";

enum BorrowerOperation {
    openTrove,
    closeTrove,
    adjustTrove
}

struct Balances {
    uint256[] collaterals;
    uint256[] debts;
    uint256[] prices;
    uint8[] decimals;
}

struct TroveManagerData {
    IERC20 collateralToken;
    uint16 index;
}

interface IBorrowerOperations is ISatoshiOwnable, ISatoshiBase, IDelegatedOps {
    event BorrowingFeePaid(address indexed borrower, IERC20 indexed collateralToken, uint256 amount);
    event CollateralConfigured(ITroveManager troveManager, IERC20 indexed collateralToken);
    event TroveCreated(address indexed _borrower, uint256 arrayIndex);
    event TroveManagerRemoved(ITroveManager indexed troveManager);
    event MinNetDebtUpdated(uint256 _minNetDebt);

    function initialize(
        ISatoshiCore _satoshiCore,
        IDebtToken _debtToken,
        IFactory _factory,
        uint256 _minNetDebt,
        uint256 _gasCompensation
    ) external;

    function addColl(
        ITroveManager _troveManager,
        address _account,
        uint256 _collateralAmount,
        address _upperHint,
        address _lowerHint
    ) external;

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

    function closeTrove(ITroveManager _troveManager, address _account) external;

    function configureCollateral(ITroveManager _troveManager, IERC20 _collateralToken) external;

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
