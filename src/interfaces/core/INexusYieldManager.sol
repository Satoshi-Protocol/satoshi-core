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
    bool isUsingOracle;
    /// The time used to wait after schedule the withdrawal.
    uint256 swapWaitingPeriod;
    /// The maximum price of the asset. If the price of the asset exceeds this value, the operation will revert.
    uint256 maxPrice;
    /// The minimum price of the asset. If the price of the asset is less than this value, the operation will revert.
    uint256 minPrice;
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

    /// @notice Event emitted when RewardManager state var is modified.
    event RewardManagerChanged(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Event emitted when stable token is swapped for debtToken.
    event AssetForDebtTokenSwapped(
        address caller, address receiver, address asset, uint256 stableIn, uint256 tokenOut, uint256 fee
    );

    /// @notice Event emitted when stable token is swapped for debtToken.
    event DebtTokenForAssetSwapped(
        address caller, address receiver, address asset, uint256 debtTokenBurnt, uint256 stableOut, uint256 fee
    );

    /// @notice Event emitted when the status of a privileged user is changed.
    event PrivilegedSet(address privileged, bool isPrivileged);

    /// @notice Event emitted when a user schedules a swapOut.
    event WithdrawalScheduled(address asset, address user, uint256 amount, uint256 fee, uint32 time);

    /// @notice Event emitted when a user withdraws the scheduled swapOut.
    event Withdraw(address asset, address user, uint256 amount);

    /// @notice Event emitted when the token is transferred.
    event TokenTransferred(address indexed token, address indexed to, uint256 amount);

    /// @notice Event emitted when the asset configuration is set.
    event AssetConfigSetting(
        address asset,
        uint256 feeIn,
        uint256 feeOut,
        uint256 debtTokenMintCap,
        uint256 dailyMintCap,
        address oracle,
        bool isUsingOracle,
        uint256 swapWaitingPeriod,
        uint256 maxPrice,
        uint256 minPrice
    );

    /// @notice Event emitted when an asset is sunset.
    event AssetSunset(address asset);

    /// @notice thrown when contract is in paused state
    error Paused();

    /// @notice thrown when attempted to pause an already paused contract
    error AlreadyPaused();

    /// @notice thrown when attempted to resume the contract if it is already resumed
    error NotPaused();

    /// @notice thrown when fee in or fee out is invalid
    error InvalidFee(uint256 feeIn, uint256 feeOut);

    /// @notice thrown when a zero address is passed as a function parameter
    error ZeroAddress();

    /// @notice thrown when a zero amount is passed as stable token amount parameter
    error ZeroAmount();

    /// @notice thrown when the user doesn't have enough debtToken balance to provide for the amount of stable tokens he wishes to get
    error NotEnoughDebtToken(uint256 debtBalance, uint256 stableTknAmount);

    /// @notice thrown when the amount of debtToken to be burnt exceeds the debtTokenMinted amount
    error DebtTokenMintedUnderflow(uint256 debtTokenMinted, uint256 stableTknAmount);

    /// @notice thrown when the debtToken is not enough to transfer
    error DebtTokenNotEnough(uint256 debtTokenAmount, uint256 transferAmount);

    /// @notice thrown when debtToken to be minted will go beyond the mintCap threshold
    error DebtTokenMintCapReached(uint256 debtTokenMinted, uint256 amountToMint, uint256 debtTokenMintCap);

    /// @notice thrown when debtToken to be minted will go beyond the daily mintCap threshold
    error DebtTokenDailyMintCapReached(uint256 dailyMinted, uint256 amountToMint, uint256 dailyDebtTokenMintCap);

    /// @notice thrown when fee calculation will result in rounding down to 0 due to stable token amount being a too small number
    error AmountTooSmall(uint256 feeAmount);

    /// @notice thrown when a user has already scheduled a swapOut
    error WithdrawalAlreadyScheduled(uint32 withdrawalTime);

    /// @notice thrown when a user tries to withdraw before the scheduled time or a user does not have a scheduled swapOut
    error WithdrawalNotAvailable(uint32 withdrawalTime);

    /// @notice thrown when the address is not privileged
    error NotPrivileged(address addr);

    /// @notice thrown when the asset is not supported
    error AssetNotSupported(address asset);

    /// @notice thrown when the price of the asset is greater than the max price or less than the min price
    error InvalidPrice(uint256 price);

    function TARGET_DIGITS() external view returns (uint256);

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function MANTISSA_ONE() external view returns (uint256);

    function ONE_DOLLAR() external view returns (uint256);

    function debtToken() external view returns (IDebtToken);

    function rewardManagerAddr() external view returns (address);

    function isPaused() external view returns (bool);

    function initialize(ISatoshiCore satoshiCore_, address debtTokenAddress_, address rewardManagerAddr_) external;

    function setAssetConfig(
        address asset,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 debtTokenMintCap_,
        uint256 dailyMintCap_,
        address oracle_,
        bool isUsingOracle_,
        uint256 swapWaitingPeriod_,
        uint256 maxPrice,
        uint256 minPrice
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

    function convertAssetToDebtTokenAmount(address asset, uint256 amount) external view returns (uint256);

    function oracle(address asset) external view returns (IPriceFeedAggregator);

    function feeIn(address asset) external view returns (uint256);

    function feeOut(address asset) external view returns (uint256);

    function debtTokenMintCap(address asset) external view returns (uint256);

    function dailyDebtTokenMintCap(address asset) external view returns (uint256);

    function debtTokenMinted(address asset) external view returns (uint256);

    function isUsingOracle(address asset) external view returns (bool);

    function swapWaitingPeriod(address asset) external view returns (uint256);

    function debtTokenDailyMintCapRemain(address asset) external view returns (uint256);

    function dailyMintCount(address asset) external view returns (uint256);

    function pendingWithdrawal(address asset, address account) external view returns (uint256, uint32);

    function pendingWithdrawals(address[] memory assets, address account)
        external
        view
        returns (uint256[] memory, uint32[] memory);

    function isAssetSupported(address asset) external view returns (bool);
}
