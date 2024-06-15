pragma solidity ^0.8.19;

import {IDebtToken} from "./IDebtToken.sol";
import {IPriceFeedAggregator} from "./IPriceFeedAggregator.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface IPegStability {

    // Helper enum for calculation of the fee.
    enum FeeDirection {
        IN,
        OUT
    }

    /// @notice Event emitted when contract is paused.
    event PSMPaused(address indexed admin);

    /// @notice Event emitted when the contract is resumed after pause.
    event PSMResumed(address indexed admin);

    /// @notice Event emitted when feeIn state var is modified.
    event FeeInChanged(uint256 oldFeeIn, uint256 newFeeIn);

    /// @notice Event emitted when feeOut state var is modified.
    event FeeOutChanged(uint256 oldFeeOut, uint256 newFeeOut);

    /// @notice Event emitted when SATMintCap state var is modified.
    event SATMintCapChanged(uint256 oldCap, uint256 newCap);

    /// @notice Event emitted when RewardManager state var is modified.
    event RewardManagerChanged(address indexed oldTreasury, address indexed newTreasury);

    /// @notice Event emitted when oracle state var is modified.
    event OracleChanged(address indexed oldOracle, address indexed newOracle);

    /// @notice Event emitted when stable token is swapped for SAT.
    event StableForSATSwapped(uint256 stableIn, uint256 SATOut, uint256 fee);

    /// @notice Event emitted when stable token is swapped for SAT.
    event SATForStableSwapped(uint256 SATBurnt, uint256 stableOut, uint256 SATFee);

    event UsingOracleSet(bool usingOracle);

    event PrivilegedSet(address privileged, bool isPrivileged);

    event SwapWaitingPeriodSet(uint256 swapWaitingPeriod);

    event WithdrawalScheduled(address indexed user, uint256 amount, uint256 fee);

    event WithdrawStable(address user, uint256 amount);

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

    /// @notice thrown when the user doesn't have enough SAT balance to provide for the amount of stable tokens he wishes to get
    error NotEnoughSAT();

    /// @notice thrown when the amount of SAT to be burnt exceeds the SATMinted amount
    error SATMintedUnderflow();

    /// @notice thrown when the SAT transfer to treasury fails
    error SATTransferFail();

    /// @notice thrown when SAT to be minted will go beyond the mintCap threshold
    error SATMintCapReached();

    /// @notice thrown when fee calculation will result in rounding down to 0 due to stable token amount being a too small number
    error AmountTooSmall();

    error WithdrawalAlreadyScheduled();

    error WithdrawalNotAvailable();

    error NotPrivileged();

    function TARGET_DIGITS() external view returns (uint256);

    function BASIS_POINTS_DIVISOR() external view returns (uint256);

    function MANTISSA_ONE() external view returns (uint256);

    function ONE_DOLLAR() external view returns (uint256);

    function SAT() external view returns (IDebtToken);

    function STABLE_TOKEN_ADDRESS() external view returns (address);

    function oracle() external view returns (IPriceFeedAggregator);

    function rewardManagerAddr() external view returns (address);

    function feeIn() external view returns (uint256);

    function feeOut() external view returns (uint256);

    function satMintCap() external view returns (uint256);

    function isPaused() external view returns (bool);   

    function usingOracle() external view returns (bool);

    function initialize(
        ISatoshiCore satoshiCore_,
        address rewardManagerAddr_,
        address oracleAddress_,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 satMintCap_,
        uint256 swapWaitingPeriod_
    ) external;

    function swapStableForSAT(
        address receiver,
        uint256 stableTknAmount
    ) external returns (uint256);

    function pause() external;

    function resume() external;

    function setFeeIn(uint256 newFeeIn) external;

    function setFeeOut(uint256 newFeeOut) external;

    function setSATMintCap(uint256 newCap) external;

    function setRewardManager(address rewardManager_) external;

    function setUsingOracle(bool usingOracle_) external;

    function setOracle(address oracle_) external;

    function setSwapWaitingPeriod(uint256 swapWaitingPeriod_) external;

    function setPrivileged(address account, bool isPrivileged_) external;

    function transerTokenToPrivilegedVault(address token, address vault, uint256 amount) external;

    function previewSwapSATForStable(uint256 stableTknAmount) external returns (uint256);

    function previewSwapStableForSAT(uint256 stableTknAmount) external returns (uint256);

    function swapSATForStablePrivileged(
        address receiver,
        uint256 stableTknAmount
    ) external returns (uint256);

    function swapStableForSATPrivileged(
        address receiver,
        uint256 stableTknAmount
    ) external returns (uint256);

    function scheduleSwapSATForStable(
        uint256 stableTknAmount
    ) external returns (uint256);

    function withdrawStable() external;

    function swapWaitingPeriod() external view returns (uint256);
}

