// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {INexusYield} from "../interfaces/core/INexusYield.sol";
import {IPriceFeedAggregator} from "../interfaces/core/IPriceFeedAggregator.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IRewardManager} from "../interfaces/core/IRewardManager.sol";

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

import {console} from "forge-std/console.sol";

/**
 * @title Nexus Yield Module Contract.
 * Mutated from:
 * https://github.com/VenusProtocol/venus-protocol/blob/develop/contracts/PegStability/PegStability.sol
 * @notice Contract for swapping stable token for SAT token and vice versa to maintain the peg stability between them.
 */
contract NexusYield is INexusYield, SatoshiOwnable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant TARGET_DIGITS = 18;

    /// @notice The divisor used to convert fees to basis points.
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    /// @notice The mantissa value representing 1 (used for calculations).
    uint256 public constant MANTISSA_ONE = 1e18;

    /// @notice The value representing one dollar in the stable token.
    /// @dev Our oracle is returning amount depending on the number of decimals of the stable token. (36 - asset_decimals) E.g. 8 decimal asset = 1e28.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public constant ONE_DOLLAR = 1e18;

    IDebtToken public immutable SAT;

    /// @notice The address of the stable token contract.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable STABLE_TOKEN_ADDRESS;

    /// @notice The address of ResilientOracle contract wrapped in its interface.
    IPriceFeedAggregator public oracle;

    /// @notice The address of the Reward Manager.
    address public rewardManagerAddr;

    /// @notice The incoming stableCoin fee. (Fee for swapStableForSAT).
    uint256 public feeIn;

    /// @notice The outgoing stableCoin fee. (Fee for swapSATForStable).
    uint256 public feeOut;

    /// @notice The maximum amount of SAT that can be minted through this contract.
    uint256 public satMintCap;

    /// @notice The total amount of SAT minted through this contract.
    uint256 public satMinted;

    /// @notice A flag indicating whether the contract is currently paused or not.
    bool public isPaused;

    /// @notice A flag indicating whether the contract is using an oracle or not.
    bool public usingOracle;

    /// @notice The time used to
    uint256 public swapWaitingPeriod;

    mapping(address => bool) public isPrivileged;

    mapping(address => uint32) public withdrawalTime;

    mapping(address => uint256) public scheduledWithdrawalAmount;

    /**
     * @dev Prevents functions to execute when contract is paused.
     */
    modifier isActive() {
        if (isPaused) revert Paused();
        _;
    }

    modifier onlyPrivileged() {
        require(isPrivileged[msg.sender], "NexusYield: caller is not privileged");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address stableTokenAddress_, address SATAddress_) {
        _ensureNonzeroAddress(stableTokenAddress_);
        _ensureNonzeroAddress(SATAddress_);

        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
        SAT = IDebtToken(SATAddress_);
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract via Proxy Contract with the required parameters.
     * @param rewardManagerAddr_ The address where fees will be sent.
     * @param oracleAddress_ The address of the ResilientOracle contract.
     * @param feeIn_ The percentage of fees to be applied to a stablecoin -> SAT swap.
     * @param feeOut_ The percentage of fees to be applied to a SAT -> stablecoin swap.
     * @param satMintCap_ The cap for the total amount of SAT that can be minted.
     */
    function initialize(
        ISatoshiCore satoshiCore_,
        address rewardManagerAddr_,
        address oracleAddress_,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 satMintCap_,
        uint256 swapWaitingPeriod_
    ) external initializer {
        __SatoshiOwnable_init(satoshiCore_);
        __ReentrancyGuard_init();

        if (feeIn_ >= BASIS_POINTS_DIVISOR || feeOut_ >= BASIS_POINTS_DIVISOR) {
            revert InvalidFee();
        }

        feeIn = feeIn_;
        feeOut = feeOut_;
        satMintCap = satMintCap_;
        rewardManagerAddr = rewardManagerAddr_;
        oracle = IPriceFeedAggregator(oracleAddress_);
        swapWaitingPeriod = swapWaitingPeriod_;
    }

    /**
     * Swap Functions **
     */

    /**
     * @notice Swaps stable tokens for SAT with fees.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the SAT tokens.
     * @param stableTknAmount The amount of stable tokens to be swapped.
     * @return Amount of SAT minted to the sender.
     */
    // @custom:event Emits StableForSATSwapped event.
    function swapStableForSAT(address receiver, uint256 stableTknAmount)
        external
        isActive
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(STABLE_TOKEN_ADDRESS).balanceOf(address(this));
        IERC20Upgradeable(STABLE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), stableTknAmount);
        uint256 balanceAfter = IERC20Upgradeable(STABLE_TOKEN_ADDRESS).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;
        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(actualTransferAmt);

        // calculate feeIn
        uint256 fee = _calculateFee(actualTransferAmtInUSD, FeeDirection.IN);
        uint256 SATToMint = actualTransferAmtInUSD - fee;

        if (satMinted + actualTransferAmtInUSD > satMintCap) {
            revert SATMintCapReached();
        }
        unchecked {
            satMinted += actualTransferAmtInUSD;
        }

        // mint SAT to receiver
        SAT.mint(receiver, SATToMint);

        // mint SAT fee to rewardManager
        if (fee != 0) {
            SAT.mint(address(this), fee);
            SAT.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        emit StableForSATSwapped(actualTransferAmt, SATToMint, fee);
        return SATToMint;
    }

    /**
     * @notice Swaps SAT for a stable token.
     * @param receiver The address where the stablecoin will be sent.
     * @param stableTknAmount The amount of stable tokens to receive.
     * @return The amount of SAT received and burnt from the sender.
     */
    // @custom:event Emits SATForStableSwapped event.
    function swapSATForStablePrivileged(address receiver, uint256 stableTknAmount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);

        // dec 18
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount);

        if (SAT.balanceOf(msg.sender) < stableTknAmountUSD) {
            revert NotEnoughSAT();
        }
        if (satMinted < stableTknAmountUSD) {
            revert SATMintedUnderflow();
        }

        unchecked {
            satMinted -= stableTknAmountUSD;
        }

        SAT.burn(msg.sender, stableTknAmountUSD);
        IERC20Upgradeable(STABLE_TOKEN_ADDRESS).safeTransfer(receiver, stableTknAmount);
        emit SATForStableSwapped(stableTknAmountUSD, stableTknAmount, 0);
        return stableTknAmountUSD;
    }

    /**
     * @notice Swaps stable tokens for SAT.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the SAT tokens.
     * @param stableTknAmount The amount of stable tokens to be swapped.
     * @return Amount of SAT minted to the sender.
     */
    // @custom:event Emits StableForSATSwapped event.
    function swapStableForSATPrivileged(address receiver, uint256 stableTknAmount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(STABLE_TOKEN_ADDRESS).balanceOf(address(this));
        IERC20Upgradeable(STABLE_TOKEN_ADDRESS).safeTransferFrom(msg.sender, address(this), stableTknAmount);
        uint256 balanceAfter = IERC20Upgradeable(STABLE_TOKEN_ADDRESS).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;

        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(actualTransferAmt);

        if (satMinted + actualTransferAmtInUSD > satMintCap) {
            revert SATMintCapReached();
        }
        unchecked {
            satMinted += actualTransferAmtInUSD;
        }

        // mint SAT to receiver
        SAT.mint(receiver, actualTransferAmtInUSD);

        emit StableForSATSwapped(actualTransferAmt, actualTransferAmtInUSD, 0);
        return actualTransferAmtInUSD;
    }

    /**
     * @notice Schedule a swap sat for stable token.
     */
    function scheduleSwapSATForStable(uint256 stableTknAmount) external isActive nonReentrant returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);

        if (withdrawalTime[msg.sender] != 0) {
            revert WithdrawalAlreadyScheduled();
        }

        withdrawalTime[msg.sender] = uint32(block.timestamp + swapWaitingPeriod);

        // dec 18
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount);
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.OUT);

        if (SAT.balanceOf(msg.sender) < stableTknAmountUSD + fee) {
            revert NotEnoughSAT();
        }
        if (satMinted < stableTknAmountUSD) {
            revert SATMintedUnderflow();
        }

        unchecked {
            satMinted -= stableTknAmountUSD;
        }

        if (fee != 0) {
            SAT.transferFrom(msg.sender, address(this), fee);
            SAT.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        SAT.burn(msg.sender, stableTknAmountUSD);
        scheduledWithdrawalAmount[msg.sender] = stableTknAmount;
        emit WithdrawalScheduled(msg.sender, stableTknAmount, fee);
        return stableTknAmountUSD;
    }

    function withdrawStable() external {
        if (withdrawalTime[msg.sender] == 0 || block.timestamp < withdrawalTime[msg.sender]) {
            revert WithdrawalNotAvailable();
        }

        withdrawalTime[msg.sender] = 0;
        uint256 _amount = scheduledWithdrawalAmount[msg.sender];
        scheduledWithdrawalAmount[msg.sender] = 0;

        // check the stable is enough
        if (IERC20(STABLE_TOKEN_ADDRESS).balanceOf(address(this)) < _amount) {
            revert SATTransferFail();
        }

        IERC20Upgradeable(STABLE_TOKEN_ADDRESS).safeTransfer(msg.sender, _amount);
        emit WithdrawStable(msg.sender, _amount);
    }

    /**
     * Admin Functions **
     */

    /**
     * @notice Pause the NYM contract.
     * @dev Reverts if the contract is already paused.
     */
    // @custom:event Emits NYMPaused event.
    function pause() external onlyOwner {
        if (isPaused) {
            revert AlreadyPaused();
        }
        isPaused = true;
        emit NYMPaused(msg.sender);
    }

    /**
     * @notice Resume the NYM contract.
     * @dev Reverts if the contract is not paused.
     */
    // @custom:event Emits NYMResumed event.
    function resume() external onlyOwner {
        if (!isPaused) {
            revert NotPaused();
        }
        isPaused = false;
        emit NYMResumed(msg.sender);
    }

    /**
     * @notice Set the fee percentage for incoming swaps.
     * @dev Reverts if the new fee percentage is invalid (greater than or equal to BASIS_POINTS_DIVISOR).
     * @param feeIn_ The new fee percentage for incoming swaps.
     */
    // @custom:event Emits FeeInChanged event.
    function setFeeIn(uint256 feeIn_) external onlyOwner {
        // feeIn = 10000 = 100%
        if (feeIn_ >= BASIS_POINTS_DIVISOR) {
            revert InvalidFee();
        }
        uint256 oldFeeIn = feeIn;
        feeIn = feeIn_;
        emit FeeInChanged(oldFeeIn, feeIn_);
    }

    /**
     * @notice Set the fee percentage for outgoing swaps.
     * @dev Reverts if the new fee percentage is invalid (greater than or equal to BASIS_POINTS_DIVISOR).
     * @param feeOut_ The new fee percentage for outgoing swaps.
     */
    // @custom:event Emits FeeOutChanged event.
    function setFeeOut(uint256 feeOut_) external onlyOwner {
        // feeOut = 10000 = 100%
        if (feeOut_ >= BASIS_POINTS_DIVISOR) {
            revert InvalidFee();
        }
        uint256 oldFeeOut = feeOut;
        feeOut = feeOut_;
        emit FeeOutChanged(oldFeeOut, feeOut_);
    }

    /**
     * @dev Set the maximum amount of SAT that can be minted through this contract.
     * @param satMintCap_ The new maximum amount of SAT that can be minted.
     */
    // @custom:event Emits SATMintCapChanged event.
    function setSATMintCap(uint256 satMintCap_) external onlyOwner {
        uint256 oldsatMintCap = satMintCap;
        satMintCap = satMintCap_;
        emit SATMintCapChanged(oldsatMintCap, satMintCap_);
    }

    function setRewardManager(address rewardManager_) external onlyOwner {
        address oldTreasuryAddress = rewardManagerAddr;
        rewardManagerAddr = rewardManager_;
        emit RewardManagerChanged(oldTreasuryAddress, rewardManager_);
    }

    function setUsingOracle(bool usingOracle_) external onlyOwner {
        usingOracle = usingOracle_;
        emit UsingOracleSet(usingOracle_);
    }

    /**
     * @notice Set the address of the ResilientOracle contract.
     * @dev Reverts if the new address is zero.
     * @param oracleAddress_ The new address of the ResilientOracle contract.
     */
    // @custom:event Emits OracleChanged event.
    function setOracle(address oracleAddress_) external onlyOwner {
        _ensureNonzeroAddress(oracleAddress_);
        address oldOracleAddress = address(oracle);
        oracle = IPriceFeedAggregator(oracleAddress_);
        emit OracleChanged(oldOracleAddress, oracleAddress_);
    }

    function setPrivileged(address account, bool isPrivileged_) external onlyOwner {
        isPrivileged[account] = isPrivileged_;
        emit PrivilegedSet(account, isPrivileged_);
    }

    function setSwapWaitingPeriod(uint256 swapWaitingPeriod_) external onlyOwner {
        swapWaitingPeriod = swapWaitingPeriod_;
        emit SwapWaitingPeriodSet(swapWaitingPeriod_);
    }

    function transerTokenToPrivilegedVault(address token, address vault, uint256 amount) external onlyOwner {
        if (!isPrivileged[vault]) {
            revert NotPrivileged();
        }
        IERC20(token).transfer(vault, amount);
        emit TokenTransferred(token, vault, amount);
    }

    /**
     * Helper Functions **
     */

    /**
     * @notice Calculates the amount of SAT that would be burnt from the user.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param stableTknAmount The amount of stable tokens to be received after the swap.
     * @return The amount of SAT that would be taken from the user.
     */
    function previewSwapSATForStable(uint256 stableTknAmount) external returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount);
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.OUT);

        if (satMinted < stableTknAmountUSD) {
            revert SATMintedUnderflow();
        }

        return stableTknAmountUSD + fee;
    }

    /**
     * @notice Calculates the amount of SAT that would be sent to the receiver.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param stableTknAmount The amount of stable tokens provided for the swap.
     * @return The amount of SAT that would be sent to the receiver.
     */
    function previewSwapStableForSAT(uint256 stableTknAmount) external returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(stableTknAmount);

        //calculate feeIn
        uint256 fee = _calculateFee(stableTknAmountUSD, FeeDirection.IN);
        uint256 SATToMint = stableTknAmountUSD - fee;

        if (satMinted + stableTknAmountUSD > satMintCap) {
            revert SATMintCapReached();
        }

        return SATToMint;
    }

    /**
     * @dev Calculates the USD value of the given amount of stable tokens depending on the swap direction.
     * @param amount The amount of stable tokens.
     * @return The USD value of the given amount of stable tokens scaled by 1e18 taking into account the direction of the swap
     */
    function _previewTokenUSDAmount(uint256 amount) internal returns (uint256) {
        return (_getScaledAmt(amount) * _getPriceInUSD()) / MANTISSA_ONE;
    }

    function _getScaledAmt(uint256 amount) internal view returns (uint256) {
        uint256 scaledAmt;
        uint256 decimals = IERC20MetadataUpgradeable(STABLE_TOKEN_ADDRESS).decimals();
        if (decimals == TARGET_DIGITS) {
            scaledAmt = amount;
        } else if (decimals < TARGET_DIGITS) {
            scaledAmt = amount * (10 ** (TARGET_DIGITS - decimals));
        } else {
            scaledAmt = amount / (10 ** (decimals - TARGET_DIGITS));
        }

        return scaledAmt;
    }

    /**
     * @notice Get the price of stable token in USD.
     * @dev This function gets the price of the stable token in USD.
     * @return The price in USD, adjusted based on the selected direction.
     */
    function _getPriceInUSD() internal returns (uint256) {
        // fetch price with decimal 18
        uint256 price = oracle.fetchPrice(IERC20(STABLE_TOKEN_ADDRESS));

        return usingOracle ? price : ONE_DOLLAR;
    }

    /**
     * @notice Calculate the fee amount based on the input amount and fee percentage.
     * @dev Reverts if the fee percentage calculation results in rounding down to 0.
     * @param amount The input amount to calculate the fee from.
     * @param direction The direction of the fee: FeeDirection.IN or FeeDirection.OUT.
     * @return The fee amount.
     */
    function _calculateFee(uint256 amount, FeeDirection direction) internal view returns (uint256) {
        uint256 feePercent;
        if (direction == FeeDirection.IN) {
            feePercent = feeIn;
        } else {
            feePercent = feeOut;
        }
        if (feePercent == 0) {
            return 0;
        } else {
            // checking if the percent calculation will result in rounding down to 0
            if (amount * feePercent < BASIS_POINTS_DIVISOR) {
                revert AmountTooSmall();
            }
            return (amount * feePercent) / BASIS_POINTS_DIVISOR;
        }
    }

    /**
     * @notice Checks that the address is not the zero address.
     * @param someone The address to check.
     */
    function _ensureNonzeroAddress(address someone) private pure {
        if (someone == address(0)) revert ZeroAddress();
    }

    /**
     * @notice Checks that the amount passed as stable tokens is bigger than zero
     * @param amount The amount to validate
     */
    function _ensureNonzeroAmount(uint256 amount) private pure {
        if (amount == 0) revert ZeroAmount();
    }
}
