// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.19;

import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
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
 * @notice Contract for swapping stable token for debtToken token and vice versa to maintain the peg stability between them.
 */
contract NexusYieldManager is INexusYieldManager, SatoshiOwnable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant TARGET_DIGITS = 18;

    /// @notice The divisor used to convert fees to basis points.
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    /// @notice The mantissa value representing 1 (used for calculations).
    uint256 public constant MANTISSA_ONE = 1e18;

    /// @notice The value representing one dollar in the stable token.
    /// @dev Our oracle is returning amount depending on the number of decimals of the asset. (36 - asset_decimals) E.g. 8 decimal asset = 1e28.
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public constant ONE_DOLLAR = 1e18;

    IDebtToken public immutable debtToken;

    /// @notice The address of the Reward Manager.
    address public rewardManagerAddr;

    /// @notice A flag indicating whether the contract is currently paused or not.
    bool public isPaused;

    uint256 public day;

    mapping(address => bool) public isPrivileged;

    mapping(address => mapping(address => uint32)) public withdrawalTime;

    mapping(address => mapping(address => uint256)) public scheduledWithdrawalAmount;

    mapping(address => AssetConfig) public assetConfigs;

    mapping(address => bool) public isAssetSupported;

    mapping(address => uint256) public dailyMintCount;

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
    constructor(address debtTokenAddress_) {
        _ensureNonzeroAddress(debtTokenAddress_);

        debtToken = IDebtToken(debtTokenAddress_);
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    /**
     * @notice Initializes the contract via Proxy Contract with the required parameters.
     * @param rewardManagerAddr_ The address where fees will be sent.
     */
    function initialize(ISatoshiCore satoshiCore_, address rewardManagerAddr_) external initializer {
        __SatoshiOwnable_init(satoshiCore_);
        __UUPSUpgradeable_init_unchained();
        __ReentrancyGuard_init();
        rewardManagerAddr = rewardManagerAddr_;
    }

    function setAssetConfig(
        address asset,
        uint256 feeIn_,
        uint256 feeOut_,
        uint256 debtTokenMintCap_,
        uint256 dailyDebtTokenMintCap_,
        address oracle_,
        bool isUsingOracle_,
        uint256 swapWaitingPeriod_
    ) external onlyOwner {
        if (feeIn_ >= BASIS_POINTS_DIVISOR || feeOut_ >= BASIS_POINTS_DIVISOR) {
            revert InvalidFee();
        }
        AssetConfig storage config = assetConfigs[asset];
        config.feeIn = feeIn_;
        config.feeOut = feeOut_;
        config.debtTokenMintCap = debtTokenMintCap_;
        config.dailyDebtTokenMintCap = dailyDebtTokenMintCap_;
        config.oracle = IPriceFeedAggregator(oracle_);
        config.isUsingOracle = isUsingOracle_;
        config.swapWaitingPeriod = swapWaitingPeriod_;
        isAssetSupported[asset] = true;

        emit AssetConfigSetting(
            asset,
            feeIn_,
            feeOut_,
            debtTokenMintCap_,
            dailyDebtTokenMintCap_,
            oracle_,
            isUsingOracle_,
            swapWaitingPeriod_
        );
    }

    function sunsetAsset(address asset) external onlyOwner {
        isAssetSupported[asset] = false;

        emit AssetSunset(asset);
    }

    /**
     * Swap Functions **
     */

    /**
     * @notice Swaps asset for debtToken with fees.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the debtToken tokens.
     * @param assetAmount The amount of asset to be swapped.
     * @return Amount of debtToken minted to the sender.
     */
    // @custom:event Emits AssetForDebtTokenSwapped event.
    function swapIn(address asset, address receiver, uint256 assetAmount)
        external
        isActive
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(asset).balanceOf(address(this));
        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        uint256 balanceAfter = IERC20Upgradeable(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;
        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        // calculate feeIn
        uint256 fee = _calculateFee(asset, actualTransferAmtInUSD, FeeDirection.IN);
        uint256 debtTokenToMint = actualTransferAmtInUSD - fee;

        if (assetConfigs[asset].debtTokenMinted + actualTransferAmtInUSD > assetConfigs[asset].debtTokenMintCap) {
            revert DebtTokenMintCapReached();
        }

        uint256 today = block.timestamp / 1 days;

        if (today > day) {
            day = today;
            dailyMintCount[asset] = 0;
        }

        if (dailyMintCount[asset] + actualTransferAmtInUSD > assetConfigs[asset].dailyDebtTokenMintCap) {
            revert DebtTokenDailyMintCapReached();
        }

        unchecked {
            assetConfigs[asset].debtTokenMinted += actualTransferAmtInUSD;
            dailyMintCount[asset] += actualTransferAmtInUSD;
        }

        // mint debtToken to receiver
        debtToken.mint(receiver, debtTokenToMint);

        // mint debtToken fee to rewardManager
        if (fee != 0) {
            debtToken.mint(address(this), fee);
            debtToken.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        emit AssetForDebtTokenSwapped(msg.sender, receiver, asset, actualTransferAmt, debtTokenToMint, fee);
        return debtTokenToMint;
    }

    /**
     * @notice Swaps debtToken for a asset.
     * @param receiver The address where the stablecoin will be sent.
     * @param amount The amount of stable tokens to receive.
     * @return The amount of asset received.
     */
    // @custom:event Emits DebtTokenForAssetSwapped event.
    function swapOutPrivileged(address asset, address receiver, uint256 amount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        AssetConfig storage config = assetConfigs[asset];

        // get asset amount
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, amount, FeeDirection.OUT);

        if (debtToken.balanceOf(msg.sender) < amount) {
            revert NotEnoughDebtToken();
        }

        if (config.debtTokenMinted < amount) {
            revert DebtTokenMintedUnderflow();
        }

        unchecked {
            config.debtTokenMinted -= amount;
        }

        debtToken.burn(msg.sender, amount);
        IERC20Upgradeable(asset).safeTransfer(receiver, assetAmount);
        emit DebtTokenForAssetSwapped(msg.sender, receiver, asset, amount, assetAmount, 0);
        return assetAmount;
    }

    /**
     * @notice Swaps stable tokens for debtToken.
     * @dev This function adds support to fee-on-transfer tokens. The actualTransferAmt is calculated, by recording token balance state before and after the transfer.
     * @param receiver The address that will receive the debtToken tokens.
     * @param assetAmount The amount of stable tokens to be swapped.
     * @return Amount of debtToken minted to the sender.
     */
    // @custom:event Emits AssetForDebtTokenSwapped event.
    function swapInPrivileged(address asset, address receiver, uint256 assetAmount)
        external
        isActive
        onlyPrivileged
        nonReentrant
        returns (uint256)
    {
        _ensureNonzeroAddress(receiver);
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        // transfer IN, supporting fee-on-transfer tokens
        uint256 balanceBefore = IERC20Upgradeable(asset).balanceOf(address(this));
        IERC20Upgradeable(asset).safeTransferFrom(msg.sender, address(this), assetAmount);
        uint256 balanceAfter = IERC20Upgradeable(asset).balanceOf(address(this));

        // calculate actual transfered amount (in case of fee-on-transfer tokens)
        uint256 actualTransferAmt = balanceAfter - balanceBefore;

        // convert to decimal 18
        uint256 actualTransferAmtInUSD = _previewTokenUSDAmount(asset, actualTransferAmt, FeeDirection.IN);

        if (assetConfigs[asset].debtTokenMinted + actualTransferAmtInUSD > assetConfigs[asset].debtTokenMintCap) {
            revert DebtTokenMintCapReached();
        }
        unchecked {
            assetConfigs[asset].debtTokenMinted += actualTransferAmtInUSD;
        }

        // mint debtToken to receiver
        debtToken.mint(receiver, actualTransferAmtInUSD);

        emit AssetForDebtTokenSwapped(msg.sender, receiver, asset, actualTransferAmt, actualTransferAmtInUSD, 0);
        return actualTransferAmtInUSD;
    }

    /**
     * @notice Schedule a swap debtToken for asset.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function scheduleSwapOut(address asset, uint256 amount) external isActive nonReentrant returns (uint256) {
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        if (withdrawalTime[asset][msg.sender] != 0) {
            revert WithdrawalAlreadyScheduled();
        }

        withdrawalTime[asset][msg.sender] = uint32(block.timestamp + assetConfigs[asset].swapWaitingPeriod);

        uint256 fee = _calculateFee(asset, amount, FeeDirection.OUT);
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, amount - fee, FeeDirection.OUT);

        if (debtToken.balanceOf(msg.sender) < amount) {
            revert NotEnoughDebtToken();
        }
        if (assetConfigs[asset].debtTokenMinted < amount - fee) {
            revert DebtTokenMintedUnderflow();
        }

        unchecked {
            assetConfigs[asset].debtTokenMinted -= amount - fee;
        }

        if (fee != 0) {
            debtToken.transferFrom(msg.sender, address(this), fee);
            debtToken.approve(rewardManagerAddr, fee);
            IRewardManager(rewardManagerAddr).increaseSATPerUintStaked(fee);
        }

        debtToken.burn(msg.sender, amount - fee);
        scheduledWithdrawalAmount[asset][msg.sender] = assetAmount;
        emit WithdrawalScheduled(asset, msg.sender, assetAmount, fee, withdrawalTime[asset][msg.sender]);
        return assetAmount;
    }

    function withdraw(address asset) external {
        if (withdrawalTime[asset][msg.sender] == 0 || block.timestamp < withdrawalTime[asset][msg.sender]) {
            revert WithdrawalNotAvailable();
        }

        withdrawalTime[asset][msg.sender] = 0;
        uint256 _amount = scheduledWithdrawalAmount[asset][msg.sender];
        scheduledWithdrawalAmount[asset][msg.sender] = 0;

        // check the asset is enough
        if (IERC20(asset).balanceOf(address(this)) < _amount) {
            revert DebtTokenTransferFail();
        }

        IERC20Upgradeable(asset).safeTransfer(msg.sender, _amount);
        emit Withdraw(asset, msg.sender, _amount);
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
     * @notice Calculates the amount of debtToken that would be burnt from the user.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param amount The amount of debt tokens used for swap.
     * @return The amount of asset that would be taken from the user.
     */
    function previewSwapOut(address asset, uint256 amount) external returns (uint256, uint256) {
        _ensureNonzeroAmount(amount);
        _ensureAssetSupported(asset);

        uint256 fee = _calculateFee(asset, amount, FeeDirection.OUT);
        uint256 assetAmount = _previewAssetAmountFromDebtToken(asset, amount - fee, FeeDirection.OUT);

        return (assetAmount, fee);
    }

    /**
     * @notice Calculates the amount of debtToken that would be sent to the receiver.
     * @dev This calculation might be off with a bit, if the price of the oracle for this asset is not updated in the block this function is invoked.
     * @param assetAmount The amount of stable tokens provided for the swap.
     * @return The amount of debtToken that would be sent to the receiver.
     */
    function previewSwapIn(address asset, uint256 assetAmount) external returns (uint256, uint256) {
        _ensureNonzeroAmount(assetAmount);
        _ensureAssetSupported(asset);

        uint256 assetAmountUSD = _previewTokenUSDAmount(asset, assetAmount, FeeDirection.IN);

        //calculate feeIn
        uint256 fee = _calculateFee(asset, assetAmountUSD, FeeDirection.IN);
        uint256 debtTokenToMint = assetAmountUSD - fee;

        return (debtTokenToMint, fee);
    }

    function convertDebtTokenToAssetAmount(address asset, uint256 amount) public view returns (uint256) {
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

    function convertAssetToDebtTokenAmount(address asset, uint256 amount) public view returns (uint256) {
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
     * @dev Calculates the USD value of the given amount of stable tokens depending on the swap direction.
     * @param amount The amount of stable tokens.
     * @return The USD value of the given amount of stable tokens scaled by 1e18 taking into account the direction of the swap
     */
    function _previewTokenUSDAmount(address asset, uint256 amount, FeeDirection direction) internal returns (uint256) {
        return (convertAssetToDebtTokenAmount(asset, amount) * _getPriceInUSD(asset, direction)) / MANTISSA_ONE;
    }

    /**
     * @dev Calculate the amount of assets from the given amount of debt tokens.
     * @param asset The address of the asset.
     * @param amount The amount of debt tokens.
     */
    function _previewAssetAmountFromDebtToken(address asset, uint256 amount, FeeDirection direction)
        internal
        returns (uint256)
    {
        return (convertDebtTokenToAssetAmount(asset, amount) * MANTISSA_ONE) / _getPriceInUSD(asset, direction);
    }

    /**
     * @notice Get the price of asset in USD.
     * @dev This function gets the price of the asset in USD.
     * @return The price in USD, adjusted based on the selected direction.
     */
    function _getPriceInUSD(address asset, FeeDirection direction) internal returns (uint256) {
        if (!assetConfigs[asset].isUsingOracle) {
            return ONE_DOLLAR;
        }

        // get price with decimals 18
        uint256 price = assetConfigs[asset].oracle.fetchPrice(IERC20(asset));

        if (direction == FeeDirection.IN) {
            // MIN(1, price)
            return price < ONE_DOLLAR ? price : ONE_DOLLAR;
        } else {
            // MAX(1, price)
            return price > ONE_DOLLAR ? price : ONE_DOLLAR;
        }
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

    function debtTokenMintCap(address asset) public view returns (uint256) {
        return assetConfigs[asset].debtTokenMintCap;
    }

    function dailyDebtTokenMintCap(address asset) public view returns (uint256) {
        return assetConfigs[asset].dailyDebtTokenMintCap;
    }

    function debtTokenMinted(address asset) public view returns (uint256) {
        return assetConfigs[asset].debtTokenMinted;
    }

    function isUsingOracle(address asset) public view returns (bool) {
        return assetConfigs[asset].isUsingOracle;
    }

    function swapWaitingPeriod(address asset) public view returns (uint256) {
        return assetConfigs[asset].swapWaitingPeriod;
    }

    function debtTokenDailyMintCapRemain(address asset) external view returns (uint256) {
        return assetConfigs[asset].dailyDebtTokenMintCap - dailyMintCount[asset];
    }

    function pendingWithdrawal(address asset, address account) external view returns (uint256, uint32) {
        return (scheduledWithdrawalAmount[asset][account], withdrawalTime[asset][account]);
    }

    function pendingWithdrawals(address[] memory assets, address account)
        external
        view
        returns (uint256[] memory, uint32[] memory)
    {
        uint256[] memory amounts = new uint256[](assets.length);
        uint32[] memory times = new uint32[](assets.length);
        for (uint256 i; i < assets.length; ++i) {
            amounts[i] = scheduledWithdrawalAmount[assets[i]][account];
            times[i] = withdrawalTime[assets[i]][account];
        }

        return (amounts, times);
    }
}
