// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {IERC20MetadataUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {INexusYieldManager, AssetConfig} from "../interfaces/core/INexusYieldManager.sol";
import {IPriceFeedAggregator} from "../interfaces/core/IPriceFeedAggregator.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IRewardManager} from "../interfaces/core/IRewardManager.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

/**
 * @title Nexus Yield Manager Contract.
 * Mutated from:
 * https://github.com/VenusProtocol/venus-protocol/blob/develop/contracts/PegStability/PegStability.sol
 * @notice Contract for swapping stable token for SAT token and vice versa to maintain the peg stability between them.
 */
contract NexusYieldManager is INexusYieldManager, SatoshiOwnable, ReentrancyGuardUpgradeable {
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

    /// @notice The address of the Reward Manager.
    address public rewardManagerAddr;

    /// @notice A flag indicating whether the contract is currently paused or not.
    bool public isPaused;

    mapping(address => bool) public isPrivileged;

    mapping(address => mapping(address => uint32)) public withdrawalTime;

    mapping(address => mapping(address => uint256)) public scheduledWithdrawalAmount;

    mapping(address => AssetConfig) public assetConfigs;

    mapping(address => bool) public isAssetSupported;

    /**
     * @dev Prevents functions to execute when contract is paused.
     */
    modifier isActive() {
        if (isPaused) revert Paused();
        _;
    }

    modifier onlyPrivileged() {
        require(isPrivileged[msg.sender], "NexusYieldManager: caller is not privileged");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address SATAddress_) {
        _ensureNonzeroAddress(SATAddress_);

        SAT = IDebtToken(SATAddress_);
        _disableInitializers();
    }

    /**
     * @notice Initializes the contract via Proxy Contract with the required parameters.
     * @param rewardManagerAddr_ The address where fees will be sent.
     */
    function initialize(ISatoshiCore satoshiCore_, address rewardManagerAddr_) external initializer {
        __SatoshiOwnable_init(satoshiCore_);
        __ReentrancyGuard_init();
        rewardManagerAddr = rewardManagerAddr_;
    }

    function setAssetConfig(
        address asset,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 satMintCap_,
        uint256 dailySatMintCap_,
        address oracle_,
        bool usingOracle_,
        uint256 swapWaitingPeriod_
    ) external onlyOwner {
        if (feeIn_ >= BASIS_POINTS_DIVISOR || feeOut_ >= BASIS_POINTS_DIVISOR) {
            revert InvalidFee();
        }
        AssetConfig storage config = assetConfigs[asset];
        config.feeIn = feeIn_;
        config.feeOut = feeOut_;
        config.satMintCap = satMintCap_;
        config.dailySatMintCap = dailySatMintCap_;
        config.oracle = IPriceFeedAggregator(oracle_);
        config.usingOracle = usingOracle_;
        config.swapWaitingPeriod = swapWaitingPeriod_;
        isAssetSupported[asset] = true;
    }

    function sunsetAsset(address asset) external onlyOwner {
        isAssetSupported[asset] = false;
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
    function swapStableForSAT(address asset, address receiver, uint256 stableTknAmount)
        external
        isActive
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(asset).balanceOf(address(this));
        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, address(this), stableTknAmount);
        uint256 balanceAfter = IERC20Upgradeable(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;
        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt);

        // calculate feeIn
        uint256 fee = _calculateFee(asset, actualTransferAmtInUSD, FeeDirection.IN);
        uint256 SATToMint = actualTransferAmtInUSD - fee;

        if (assetConfigs[asset].satMinted + actualTransferAmtInUSD > assetConfigs[asset].satMintCap) {
            revert SATMintCapReached();
        }
        unchecked {
            assetConfigs[asset].satMinted += actualTransferAmtInUSD;
        }

        // mint SAT to receiver
        SAT.mint(receiver, SATToMint);

        // mint SAT fee to rewardManager
        if (fee != 0) {
            SAT.mint(address(this), fee);
            SAT.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        emit StableForSATSwapped(msg.sender, receiver, actualTransferAmt, SATToMint, fee);
        return SATToMint;
    }

    /**
     * @notice Swaps SAT for a stable token.
     * @param receiver The address where the stablecoin will be sent.
     * @param stableTknAmount The amount of stable tokens to receive.
     * @return The amount of SAT received and burnt from the sender.
     */
    // @custom:event Emits SATForStableSwapped event.
    function swapSATForStablePrivileged(address asset, address receiver, uint256 stableTknAmount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        AssetConfig storage config = assetConfigs[asset];

        // dec 18
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(asset, stableTknAmount);

        if (SAT.balanceOf(msg.sender) < stableTknAmountUSD) {
            revert NotEnoughSAT();
        }
        if (config.satMinted < stableTknAmountUSD) {
            revert SATMintedUnderflow();
        }

        unchecked {
            config.satMinted -= stableTknAmountUSD;
        }

        SAT.burn(msg.sender, stableTknAmountUSD);
        IERC20Upgradeable(asset).safeTransfer(receiver, stableTknAmount);
        emit SATForStableSwapped(msg.sender, receiver, asset, stableTknAmountUSD, stableTknAmount, 0);
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
    function swapStableForSATPrivileged(address asset, address receiver, uint256 stableTknAmount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(asset).balanceOf(address(this));
        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, address(this), stableTknAmount);
        uint256 balanceAfter = IERC20Upgradeable(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;

        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt);

        if (assetConfigs[asset].satMinted + actualTransferAmtInUSD > assetConfigs[asset].satMintCap) {
            revert SATMintCapReached();
        }
        unchecked {
            assetConfigs[asset].satMinted += actualTransferAmtInUSD;
        }

        // mint SAT to receiver
        SAT.mint(receiver, actualTransferAmtInUSD);

        emit StableForSATSwapped(msg.sender, receiver, actualTransferAmt, actualTransferAmtInUSD, 0);
        return actualTransferAmtInUSD;
    }

    /**
     * @notice Schedule a swap sat for stable token.
     */
    function scheduleSwapSATForStable(address asset, uint256 stableTknAmount)
        external
        isActive
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        if (withdrawalTime[asset][msg.sender] != 0) {
            revert WithdrawalAlreadyScheduled();
        }

        withdrawalTime[asset][msg.sender] = uint32(block.timestamp + assetConfigs[asset].swapWaitingPeriod);

        // dec 18
        uint256 stableTknAmountUSD = _previewTokenUSDAmount(asset, stableTknAmount);
        uint256 fee = _calculateFee(asset, stableTknAmountUSD, FeeDirection.OUT);

        if (SAT.balanceOf(msg.sender) < stableTknAmountUSD + fee) {
            revert NotEnoughSAT();
        }
        if (assetConfigs[asset].satMinted < stableTknAmountUSD) {
            revert SATMintedUnderflow();
        }

        unchecked {
            assetConfigs[asset].satMinted -= stableTknAmountUSD;
        }

        if (fee != 0) {
            SAT.transferFrom(msg.sender, address(this), fee);
            SAT.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        SAT.burn(msg.sender, stableTknAmountUSD);
        scheduledWithdrawalAmount[asset][msg.sender] = stableTknAmount;
        emit WithdrawalScheduled(asset, msg.sender, stableTknAmount, fee);
        return stableTknAmountUSD;
    }

    function withdrawStable(address asset) external {
        if (withdrawalTime[asset][msg.sender] == 0 || block.timestamp < withdrawalTime[asset][msg.sender]) {
            revert WithdrawalNotAvailable();
        }

        withdrawalTime[asset][msg.sender] = 0;
        uint256 _amount = scheduledWithdrawalAmount[asset][msg.sender];
        scheduledWithdrawalAmount[asset][msg.sender] = 0;

        // check the stable is enough
        if (IERC20(asset).balanceOf(address(this)) < _amount) {
            revert SATTransferFail();
        }

        IERC20Upgradeable(asset).safeTransfer(msg.sender, _amount);
        emit WithdrawStable(asset, msg.sender, _amount);
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

    function setRewardManager(address rewardManager_) external onlyOwner {
        address oldTreasuryAddress = rewardManagerAddr;
        rewardManagerAddr = rewardManager_;
        emit RewardManagerChanged(oldTreasuryAddress, rewardManager_);
    }

    function setPrivileged(address account, bool isPrivileged_) external onlyOwner {
        isPrivileged[account] = isPrivileged_;
        emit PrivilegedSet(account, isPrivileged_);
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
    function previewSwapSATForStable(address asset, uint256 stableTknAmount) external returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        uint256 stableTknAmountUSD = _previewTokenUSDAmount(asset, stableTknAmount);
        uint256 fee = _calculateFee(asset, stableTknAmountUSD, FeeDirection.OUT);

        if (assetConfigs[asset].satMinted < stableTknAmountUSD) {
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
    function previewSwapStableForSAT(address asset, uint256 stableTknAmount) external returns (uint256) {
        _ensureNonzeroAmount(stableTknAmount);
        _ensureAssetSupported(asset);

        uint256 stableTknAmountUSD = _previewTokenUSDAmount(asset, stableTknAmount);

        //calculate feeIn
        uint256 fee = _calculateFee(asset, stableTknAmountUSD, FeeDirection.IN);
        uint256 SATToMint = stableTknAmountUSD - fee;

        if (assetConfigs[asset].satMinted + stableTknAmountUSD > assetConfigs[asset].satMintCap) {
            revert SATMintCapReached();
        }

        return SATToMint;
    }

    function convertSATToStableAmount(address asset, uint256 amount) external view returns (uint256) {
        uint256 scaledAmt;
        uint256 decimals = IERC20MetadataUpgradeable(asset).decimals();
        if (decimals == TARGET_DIGITS) {
            scaledAmt = amount;
        } else if (decimals < TARGET_DIGITS) {
            scaledAmt = amount / (10 ** (TARGET_DIGITS - decimals));
        } else {
            scaledAmt = amount * (10 ** (decimals - TARGET_DIGITS));
        }

        return scaledAmt;
    }

    /**
     * @dev Calculates the USD value of the given amount of stable tokens depending on the swap direction.
     * @param amount The amount of stable tokens.
     * @return The USD value of the given amount of stable tokens scaled by 1e18 taking into account the direction of the swap
     */
    function _previewTokenUSDAmount(address asset, uint256 amount) internal returns (uint256) {
        return (_getScaledAmt(asset, amount) * _getPriceInUSD(asset)) / MANTISSA_ONE;
    }

    function _getScaledAmt(address asset, uint256 amount) internal view returns (uint256) {
        uint256 scaledAmt;
        uint256 decimals = IERC20MetadataUpgradeable(asset).decimals();
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
    function _getPriceInUSD(address asset) internal returns (uint256) {
        // fetch price with decimal 18

        return assetConfigs[asset].usingOracle ? assetConfigs[asset].oracle.fetchPrice(IERC20(asset)) : ONE_DOLLAR;
    }

    /**
     * @notice Calculate the fee amount based on the input amount and fee percentage.
     * @dev Reverts if the fee percentage calculation results in rounding down to 0.
     * @param amount The input amount to calculate the fee from.
     * @param direction The direction of the fee: FeeDirection.IN or FeeDirection.OUT.
     * @return The fee amount.
     */
    function _calculateFee(address asset, uint256 amount, FeeDirection direction) internal view returns (uint256) {
        uint256 feePercent;
        if (direction == FeeDirection.IN) {
            feePercent = assetConfigs[asset].feeIn;
        } else {
            feePercent = assetConfigs[asset].feeOut;
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

    function _ensureAssetSupported(address asset) private view {
        if (!isAssetSupported[asset]) {
            revert AssetNotSupported();
        }
    }

    function oracle(address asset) public view returns (IPriceFeedAggregator) {
        return assetConfigs[asset].oracle;
    }

    function feeIn(address asset) public view returns (uint256) {
        return assetConfigs[asset].feeIn;
    }

    function feeOut(address asset) public view returns (uint256) {
        return assetConfigs[asset].feeOut;
    }

    function satMintCap(address asset) public view returns (uint256) {
        return assetConfigs[asset].satMintCap;
    }

    function dailySatMintCap(address asset) public view returns (uint256) {
        return assetConfigs[asset].dailySatMintCap;
    }

    function satMinted(address asset) public view returns (uint256) {
        return assetConfigs[asset].satMinted;
    }

    function usingOracle(address asset) public view returns (bool) {
        return assetConfigs[asset].usingOracle;
    }

    function swapWaitingPeriod(address asset) public view returns (uint256) {
        return assetConfigs[asset].swapWaitingPeriod;
    }
}
