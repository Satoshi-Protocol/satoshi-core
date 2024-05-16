// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IRewardManager, LockDuration, NUMBER_OF_LOCK_DURATIONS} from "../interfaces/core/IRewardManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IWETH} from "../helpers/interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";

/**
 * @title Reward Manager Contract
 *
 *        Receive and manage protocol fees.
 *        Stake OSHI to receive sOSHI (lock weight) and gain protocol fees.
 *        stake 3 months: 1x, 6 months: 2x, 9 months: 3x, 12 months: 4x
 *        The lock weight will not decay.
 */
contract RewardManager is IRewardManager, SatoshiOwnable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IDebtToken;
    using SafeERC20Upgradeable for IOSHIToken;
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_PRECISION = 1e27;
    uint256 public constant FEE_TO_STAKER_RATIO = 975;
    uint256 public constant FEE_RATIO_BASE = 1000;

    uint256 internal constant DURATION_MULTIPLIER = 3; // 3 months = 1x, 6 months = 2x, 9 months = 3x, 12 months = 4x
    uint256 internal constant ONE_MONTH = 30 days;

    IDebtToken public debtToken;
    IOSHIToken public oshiToken;
    IERC20[] public collToken;
    IWETH public weth;

    IBorrowerOperations public borrowerOperations;
    mapping(address => bool) public isTroveManagerRegistered;
    mapping(address => uint256) public collTokenIndex;

    uint256 public totalOSHIWeightedStaked;

    uint256[] public F_COLL; // running sum of Coll fees per-OSHI-point-staked
    uint256 public F_SAT; // running sum of SAT fees per-OSHI-point-staked

    uint256[] public collForFeeReceiver;
    uint256 public satForFeeReceiver;

    // User snapshots of F_SAT and F_COLL, taken at the point at which their latest deposit was made
    mapping(address => Snapshot) internal snapshots;
    mapping(address => mapping(uint256 => Stake[])) internal userStakes;
    mapping(address => StakeData) internal stakeData;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
    }

    // --- External Functions ---
    function stake(uint256 _amount, LockDuration _duration) external {
        require(_amount > 0, "RewardManager: Amount must be greater than 0");
        oshiToken.safeTransferFrom(msg.sender, address(this), _amount);

        StakeData storage data = stakeData[msg.sender];

        Stake memory newStake = Stake({
            staker: msg.sender,
            amount: _amount,
            lockDuration: _duration,
            endTime: uint32(block.timestamp + _calculateDurationTimeStamp(_duration))
        });

        userStakes[msg.sender][uint256(_duration)].push(newStake);

        uint256 currentWeight = data.lockWeights;

        uint256[] memory CollGain;
        uint256 SATGain;

        if (currentWeight != 0) {
            CollGain = _getPendingCollGain(msg.sender);
            SATGain = _getPendingSATGain(msg.sender);
        }

        _updateUserSnapshots(msg.sender);

        uint256 newWeight = currentWeight + _calculateLockWeight(_amount, _duration);

        // Increase user’s lock weight and total OSHI staked (weighted)
        data.lockWeights = newWeight;
        totalOSHIWeightedStaked += _calculateLockWeight(_amount, _duration);

        emit StakeChanged(msg.sender, newWeight);
        emit StakingGainsWithdrawn(msg.sender, CollGain, SATGain);

        // transfer gains to user
        if (currentWeight != 0) {
            _sendDebtToken(SATGain);
            for (uint256 i; i < collToken.length; ++i) {
                _sendCollToken(collToken[i], CollGain[i]);
            }
        }
    }

    function unstake(uint256 _amount) external {
        StakeData storage data = stakeData[msg.sender];
        uint32[NUMBER_OF_LOCK_DURATIONS] storage nextUnlockIndex = data.nextUnlockIndex;
        uint256 currentWeight = data.lockWeights;
        uint256 OSHIToWithdraw;
        uint256 weightDecreased;
        for (uint256 i; i < NUMBER_OF_LOCK_DURATIONS; ++i) {
            Stake[] memory userStake = userStakes[msg.sender][i];
            for (uint256 j = nextUnlockIndex[i]; j < userStake.length; ++j) {
                if (userStake[j].endTime > block.timestamp || OSHIToWithdraw == _amount) break;
                if (OSHIToWithdraw < _amount && userStake[j].amount > 0 && userStake[j].endTime <= block.timestamp) {
                    uint256 withdrawAmount = SatoshiMath._min(_amount - OSHIToWithdraw, userStake[j].amount);
                    OSHIToWithdraw += withdrawAmount;
                    weightDecreased += _calculateLockWeight(withdrawAmount, userStake[j].lockDuration);
                    // remove stake amount
                    userStakes[msg.sender][i][j].amount -= withdrawAmount;
                }
                // set next unlock index
                if (userStakes[msg.sender][i][j].amount == 0) {
                    nextUnlockIndex[i]++;
                }
            }
            // update next unlock index
            data.nextUnlockIndex[i] = nextUnlockIndex[i];
        }

        uint256[] memory CollGain = _getPendingCollGain(msg.sender);
        uint256 SATGain = _getPendingSATGain(msg.sender);

        _updateUserSnapshots(msg.sender);

        require(OSHIToWithdraw != 0, "RewardManager: No OSHI to withdraw");

        if (OSHIToWithdraw != 0) {
            uint256 newWeight = currentWeight - weightDecreased;

            // Decrease user's lock weight and total OSHI staked (weighted)
            data.lockWeights = newWeight;
            totalOSHIWeightedStaked -= weightDecreased;
            emit TotalOSHIStakedUpdated(totalOSHIWeightedStaked);

            // Transfer unstaked OSHI to user
            oshiToken.safeTransfer(msg.sender, OSHIToWithdraw);

            emit StakeChanged(msg.sender, newWeight);
        }

        emit StakingGainsWithdrawn(msg.sender, CollGain, SATGain);

        // send gains to user
        _sendDebtToken(SATGain);
        for (uint256 i; i < collToken.length; ++i) {
            _sendCollToken(collToken[i], CollGain[i]);
        }
    }

    function claimReward() external {
        uint256[] memory CollGain = _getPendingCollGain(msg.sender);
        uint256 SATGain = _getPendingSATGain(msg.sender);

        _updateUserSnapshots(msg.sender);

        emit StakingGainsWithdrawn(msg.sender, CollGain, SATGain);

        // send gains to user
        _sendDebtToken(SATGain);
        for (uint256 i; i < collToken.length; ++i) {
            _sendCollToken(collToken[i], CollGain[i]);
        }
    }

    function increaseCollPerUintStaked(uint256 _amount) external {
        _isVaildCaller();

        address collateralToken = address(ITroveManager(msg.sender).collateralToken());
        uint256 index = collTokenIndex[collateralToken];
        uint256 collFeePerOSHIStaked;

        IERC20(collateralToken).safeTransferFrom(msg.sender, address(this), _amount);

        if (totalOSHIWeightedStaked > 0) {
            uint256 _amountToStaker = _amount * FEE_TO_STAKER_RATIO / FEE_RATIO_BASE;
            uint256 _amountToFeeReceiver = _amount - _amountToStaker;
            collFeePerOSHIStaked = _amountToStaker * DECIMAL_PRECISION / totalOSHIWeightedStaked;
            collForFeeReceiver[index] += _amountToFeeReceiver;
        } else {
            // when no OSHI is staked
            collForFeeReceiver[index] += _amount;
        }

        F_COLL[index] += collFeePerOSHIStaked;
        emit F_COLLUpdated(collateralToken, F_COLL[index]);
    }

    function increaseSATPerUintStaked(uint256 _amount) external {
        _isVaildCaller();

        debtToken.safeTransferFrom(msg.sender, address(this), _amount);

        uint256 SATFeePerOSHIStaked;

        if (totalOSHIWeightedStaked > 0) {
            uint256 _amountToStaker = _amount * FEE_TO_STAKER_RATIO / FEE_RATIO_BASE;
            uint256 _amountToFeeReceiver = _amount - _amountToStaker;
            SATFeePerOSHIStaked = _amountToStaker * DECIMAL_PRECISION / totalOSHIWeightedStaked;
            satForFeeReceiver += _amountToFeeReceiver;
        } else {
            // when no OSHI is staked
            satForFeeReceiver += _amount;
        }

        F_SAT += SATFeePerOSHIStaked;
        emit F_SATUpdated(F_SAT);
    }

    // --- Pending reward functions ---

    function getPendingCollGain(address _user) external view returns (uint256[] memory) {
        return _getPendingCollGain(_user);
    }

    function _getPendingCollGain(address _user) internal view returns (uint256[] memory) {
        uint256 collTokenLength = collToken.length;
        uint256[] memory CollGain = new uint256[](collTokenLength);
        for (uint256 i; i < collTokenLength; ++i) {
            uint256 F_COLL_Snapshot = snapshots[_user].F_COLL_Snapshot[i];
            CollGain[i] = stakeData[_user].lockWeights * (F_COLL[i] - F_COLL_Snapshot) / DECIMAL_PRECISION;
        }
        return CollGain;
    }

    function getPendingSATGain(address _user) external view returns (uint256) {
        return _getPendingSATGain(_user);
    }

    function _getPendingSATGain(address _user) internal view returns (uint256) {
        uint256 F_SAT_Snapshot = snapshots[_user].F_SAT_Snapshot;
        uint256 SATGain = stakeData[_user].lockWeights * (F_SAT - F_SAT_Snapshot) / DECIMAL_PRECISION;
        return SATGain;
    }

    function getAvailableUnstakeAmount(address _user) external view returns (uint256) {
        uint32[NUMBER_OF_LOCK_DURATIONS] memory nextUnlockIndex = stakeData[_user].nextUnlockIndex;
        uint256 availableUnstakeAmount;
        for (uint256 i; i < NUMBER_OF_LOCK_DURATIONS; ++i) {
            Stake[] memory userStake = userStakes[_user][i];
            for (uint256 j = nextUnlockIndex[i]; j < userStake.length; ++j) {
                if (userStake[j].endTime > block.timestamp) break;
                availableUnstakeAmount += userStake[j].amount;
            }
        }
        return availableUnstakeAmount;
    }

    function getSnapshot(address _user) external view returns (Snapshot memory) {
        return snapshots[_user];
    }

    function getUserStakes(address _user, uint256 _index) external view returns (Stake[] memory) {
        return userStakes[_user][_index];
    }

    function getStakeData(address _user) external view returns (StakeData memory) {
        return stakeData[_user];
    }

    // --- Admin Functions ---
    function registerTroveManager(ITroveManager _troveManager) external onlyOwner {
        isTroveManagerRegistered[address(_troveManager)] = true;
        IERC20 collateralToken = _troveManager.collateralToken();
        require(address(collateralToken) != address(0), "RewardManager: Invalid collateral token");
        collToken.push(collateralToken);
        collTokenIndex[address(collateralToken)] = collToken.length - 1;
        F_COLL.push(0);
        collForFeeReceiver.push(0);
        emit TroveManagerRegistered(_troveManager);
    }

    function removeTroveManager(ITroveManager _troveManager) external onlyOwner {
        isTroveManagerRegistered[address(_troveManager)] = false;
        emit TroveManagerRemoved(_troveManager);
    }

    function setAddresses(
        IBorrowerOperations _borrowerOperations,
        IWETH _weth,
        IDebtToken _debtToken,
        IOSHIToken _oshiToken
    ) external onlyOwner {
        borrowerOperations = _borrowerOperations;
        weth = _weth;
        debtToken = _debtToken;
        oshiToken = _oshiToken;
        emit BorrowerOperationsSet(_borrowerOperations);
        emit DebtTokenSet(_debtToken);
        emit WETHSet(_weth);
    }

    function claimFee() external onlyOwner {
        if (satForFeeReceiver != 0) {
            debtToken.safeTransfer(SATOSHI_CORE.feeReceiver(), satForFeeReceiver);
            satForFeeReceiver = 0;
        }
        for (uint256 i; i < collToken.length; ++i) {
            if (collForFeeReceiver[i] != 0) {
                collToken[i].safeTransfer(SATOSHI_CORE.feeReceiver(), collForFeeReceiver[i]);
                collForFeeReceiver[i] = 0;
            }
        }
    }

    // --- Internal Functions ---
    function _updateUserSnapshots(address _user) internal {
        uint256 length = collToken.length;
        for (uint256 i; i < length; ++i) {
            snapshots[_user].F_COLL_Snapshot[i] = F_COLL[i];
        }
        snapshots[_user].F_SAT_Snapshot = F_SAT;
        emit StakerSnapshotsUpdated(_user, F_COLL, F_SAT);
    }

    function _calculateLockWeight(uint256 _amount, LockDuration _duration) internal pure returns (uint256) {
        return _amount * (uint256(_duration) + 1);
    }

    function _calculateDurationTimeStamp(LockDuration _duration) internal pure returns (uint256) {
        return (DURATION_MULTIPLIER + uint256(_duration) * DURATION_MULTIPLIER) * ONE_MONTH;
    }

    function _sendCollToken(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == address(weth)) {
            IWETH(weth).withdraw(collAmount);
            (bool success,) = payable(msg.sender).call{value: collAmount}("");
            if (!success) revert NativeTokenTransferFailed();
        } else {
            collateralToken.safeTransfer(msg.sender, collAmount);
        }
    }

    function _sendDebtToken(uint256 debtAmount) private {
        if (debtAmount == 0) return;

        debtToken.safeTransfer(msg.sender, debtAmount);
    }

    // --- Require ---

    function _isVaildCaller() internal view {
        bool isRegistered;
        if (
            msg.sender == SATOSHI_CORE.owner() || msg.sender == address(borrowerOperations)
                || msg.sender == address(debtToken) || msg.sender == SATOSHI_CORE.feeReceiver()
                || isTroveManagerRegistered[msg.sender]
        ) isRegistered = true;
        require(isRegistered, "RewardManager: Caller is not Valid");
    }
}
