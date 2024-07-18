pragma solidity ^0.8.19;

import {IDebtToken} from "./IDebtToken.sol";
import {IPriceFeedAggregator} from "./IPriceFeedAggregator.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";

struct AssetConfig {
    /// The address of ResilientOracle contract wrapped in its interface.
    IPriceFeedAggregator oracle;
    /// The incoming stableCoin fee. (Fee for swapIn).
    uint256 feeIn;
    /// The outgoing stableCoin fee. (Fee for swapOut).
    uint256 feeOut;
    /// The maximum amount of debtToken that can be minted through this contract.
    uint256 debtTokenMintCap;
    /// The maximum amount of debtToken that can be minted everyday.
    uint256 dailyDebtTokenMintCap;
    /// The total amount of debtToken minted through this asset.
    uint256 debtTokenMinted;
    /// A flag indicating whether the contract is using an oracle or not.
    bool usingOracle;
    /// The time used to
    uint256 swapWaitingPeriod;
}

interface INexusYieldManager is ISatoshiOwnable {
    // Helper enum for calculation of the fee.
    enum FeeDirection {
        IN,
        OUT
    }

    /// @notice Event emitted when contract is paused.
    event NYMPaused(address indexed admin);

    /// @notice Event emitted when the contract is resumed after pause.
    event NYMResumed(address indexed admin);

    /// @notice Event emitted when feeIn state var is modified.
    event FeeInChanged(uint256 oldFeeIn, uint256 newFeeIn);

    /// @notice Event emitted when feeOut state var is modified.
    event FeeOutChanged(uint256 oldFeeOut, uint256 newFeeOut);

    /// @notice Event emitted when SATMintCap state var is modified.
    event DebtTokenMintCapChanged(uint256 oldCap, uint256 newCap);

    /// @notice Event emitted when RewardManager state var is modified.
    event RewardManagerChanged(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Event emitted when oracle state var is modified.
    event OracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when stable token is swapped for debtToken.
    event AssetForDebtTokenSwapped(address caller, address receiver, uint256 stableIn, uint256 SATOut, uint256 fee);

    /// @notice Event emitted when stable token is swapped for debtToken.
    event DebtTokenForAssetSwapped(
        address caller, address receiver, address asset, uint256 debtTokenBurnt, uint256 stableOut, uint256 fee
    );

    event UsingOracleSet(bool usingOracle);

    event PrivilegedSet(address privileged, bool isPrivileged);

    event SwapWaitingPeriodSet(uint256 swapWaitingPeriod);

    event WithdrawalScheduled(address asset, address user, uint256 amount, uint256 fee);

    event Withdraw(address asset, address user, uint256 amount);

    event TokenTransferred(address indexed token, address indexed to, uint256 amount);

    /// @notice thrown when contract is in paused state
    error Paused();

    /// @notice thrown when attempted to pause an already paused contract
    error AlreadyPaused();

    /// @notice thrown when attempted to resume the contract if it is already resumed
    error NotPaused();

    /// @notice thrown when stable token has more than 18 decimals
    error TooManyDecimals();

    /// @notice thrown when fee is >= 100%
    error InvalidFee();

    /// @notice thrown when a zero address is passed as a function parameter
    error ZeroAddress();

    /// @notice thrown when a zero amount is passed as stable token amount parameter
    error ZeroAmount();

    /// @notice thrown when the user doesn't have enough debtToken balance to provide for the amount of stable tokens he wishes to get
    error NotEnoughDebtToken();

    /// @notice thrown when the amount of debtToken to be burnt exceeds the debtTokenMinted amount
    error DebtTokenMintedUnderflow();

    /// @notice thrown when the debtToken transfer to treasury fails
    error DebtTokenTransferFail();

    /// @notice thrown when debtToken to be minted will go beyond the mintCap threshold
    error DebtTokenMintCapReached();

    error DebtTokenDailyMintCapReached();

    /// @notice thrown when fee calculation will result in rounding down to 0 due to stable token amount being a too small number
    error AmountTooSmall();

    error WithdrawalAlreadyScheduled();

    error WithdrawalNotAvailable();

    error NotPrivileged();

    error AssetNotSupported();

    function TARGET_DIGITS() external view returns (uint256);

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function MANTISSA_ONE() external view returns (uint256);

    function ONE_DOLLAR() external view returns (uint256);

    function debtToken() external view returns (IDebtToken);

    function rewardManagerAddr() external view returns (address);

    function isPaused() external view returns (bool);

    function initialize(ISatoshiCore satoshiCore_, address rewardManagerAddr) external;

    function setAssetConfig(
        address asset,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 debtTokenMintCap_,
        uint256 dailyMintCap_,
        address oracle_,
        bool usingOracle_,
        uint256 swapWaitingPeriod_
    ) external;

    function sunsetAsset(address asset) external;

    function swapIn(address asset, address receiver, uint256 stableTknAmount) external returns (uint256);

    function pause() external;

    function resume() external;

    function setRewardManager(address rewardManager_) external;

    function setPrivileged(address account, bool isPrivileged_) external;

    function transerTokenToPrivilegedVault(address token, address vault, uint256 amount) external;

    function previewSwapOut(address asset, uint256 stableTknAmount) external returns (uint256, uint256);

    function previewSwapIn(address asset, uint256 stableTknAmount) external returns (uint256, uint256);

    function swapOutPrivileged(address asset, address receiver, uint256 stableTknAmount) external returns (uint256);

    function swapInPrivileged(address asset, address receiver, uint256 stableTknAmount) external returns (uint256);

    function scheduleSwapOut(address asset, uint256 stableTknAmount) external returns (uint256);

    function withdraw(address asset) external;

    function convertDebtTokenToAssetAmount(address asset, uint256 amount) external view returns (uint256);

    function oracle(address asset) external view returns (IPriceFeedAggregator);

    function feeIn(address asset) external view returns (uint256);

    function feeOut(address asset) external view returns (uint256);

    function debtTokenMintCap(address asset) external view returns (uint256);

    function dailyDebtTokenMintCap(address asset) external view returns (uint256);

    function debtTokenMinted(address asset) external view returns (uint256);

    function usingOracle(address asset) external view returns (bool);

    function swapWaitingPeriod(address asset) external view returns (uint256);

    function debtTokenDailyMintCapRemain(address asset) external view returns (uint256);

    function dailyMintCount(address asset) external view returns (uint256);
}
