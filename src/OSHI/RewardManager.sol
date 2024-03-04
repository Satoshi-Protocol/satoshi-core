// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IRewardManager} from "../interfaces/core/IRewardManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../helpers/interfaces/IWETH.sol";

/**
 * @title Reward Manager Contract
 *
 *        Receive and manage protocol fees.
 *        Stake OSHI to receive sOSHI (lock weight) and gain protocol fees.
 *        stake 3 months: 1x, 6 months: 2x, 9 months: 3x, 12 months: 4x
 *        The lock weight will not decay.
 */
contract RewardManager is IRewardManager, SatoshiOwnable {
    using SafeERC20 for IERC20;

    uint256 public constant DECIMAL_PRECISION = 1e18;

    IERC20 public debtToken;
    IERC20 public oshiToken;
    IERC20[] public collToken;
    address public weth;

    address public borrowerOperationsAddress;
    address[] public registeredTroveManagers;
    mapping(address => uint256) public collTokenIndex;

    mapping(address => uint256) public stakes;
    uint256 public totalOSHIWeightedStaked;

    uint256[] public F_COLL; // running sum of Coll fees per-OSHI-point-staked
    uint256 public F_SAT; // running sum of SAT fees per-OSHI-point-staked

    uint256 collForFeeReceiver;
    uint256 satForFeeReceiver;

    // User snapshots of F_SAT and F_COLL, taken at the point at which their latest deposit was made
    mapping(address => Snapshot) public snapshots;
    mapping(address => mapping(uint256 => Stake[])) public userStakes;
    mapping(address => StakeData) public stakeData;
    mapping(address => uint256) public userLockWeights;

    constructor(ISatoshiCore _satoshiCore) {
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
            startTime: uint32(block.timestamp),
            endTime: uint32(block.timestamp + (3 + uint(_duration) * 3) * 30 days)
        });

        userStakes[msg.sender][uint(_duration)].push(newStake);

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
            for (uint i; i < collToken.length; ++i) {
                _sendCollToken(collToken[i], CollGain[i]);
            }
        }
    }

    function unstake(uint256 _amount) external {
        StakeData storage data = stakeData[msg.sender];
        uint32[4] memory nextUnlockIndex = data.nextUnlockIndex;
        uint256 currentWeight = data.lockWeights;
        uint256 OSHIToWithdraw;
        uint256 weightDecreased;
        for (uint256 i; i < 4; ++i) {
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
                nextUnlockIndex[i]++;
            }
            // update next unlock index
            data.nextUnlockIndex[i] = nextUnlockIndex[i];
        }

        uint256[] memory CollGain = _getPendingCollGain(msg.sender);
        uint256 SATGain = _getPendingSATGain(msg.sender);

        _updateUserSnapshots(msg.sender);

        if (OSHIToWithdraw > 0) {
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
        for (uint i; i < collToken.length; ++i) {
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
        for (uint i; i < collToken.length; ++i) {
            _sendCollToken(collToken[i], CollGain[i]);
        }
    }

    function increaseCollPerUintStaked(uint256 _amount) external {
        _isCallerTroveManager();
        address collateralToken = address(ITroveManager(msg.sender).collateralToken());
        uint256 index = collTokenIndex[collateralToken];
        uint256 collFeePerOSHIStaked;

        if (totalOSHIWeightedStaked > 0) {
            uint256 _amountToStaker = _amount * 975 / 1000;
            uint256 _amountToFeeReceiver = _amount - _amountToStaker;
            collFeePerOSHIStaked = _amountToStaker * DECIMAL_PRECISION / totalOSHIWeightedStaked;
            collForFeeReceiver += _amountToFeeReceiver;
        } else {
            // when no OSHI is staked
            collForFeeReceiver += _amount;
        }

        F_COLL[index] += collFeePerOSHIStaked;
        emit F_COLLUpdated(collateralToken, F_COLL[index]);
    }

    function increaseSATPerUintStaked(uint256 _amount) external {
        _isCallerBorrowerOperationsOrDebtToken();
        uint256 SATFeePerOSHIStaked;

        if (totalOSHIWeightedStaked > 0) {
            uint256 _amountToStaker = _amount * 975 / 1000;
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
        uint256[] memory CollGain;
        for (uint i; i < collToken.length; ++i) {
            uint256 F_COLL_Snapshot = snapshots[_user].F_COLL_Snapshot[i];
            CollGain[i] = stakes[_user] * (F_COLL[i] - F_COLL_Snapshot) / DECIMAL_PRECISION;
        }
        return CollGain;
    }

    function getPendingSATGain(address _user) external view returns (uint256) {
        return _getPendingSATGain(_user);
    }

    function _getPendingSATGain(address _user) internal view returns (uint256) {
        uint256 F_SAT_Snapshot = snapshots[_user].F_SAT_Snapshot;
        uint256 SATGain = stakes[_user] * (F_SAT - F_SAT_Snapshot) / DECIMAL_PRECISION;
        return SATGain;
    }

    // --- Admin Functions ---
    function registerTroveManager(address _troveManager) external onlyOwner {
        registeredTroveManagers.push(_troveManager);
        IERC20 collateralToken = ITroveManager(_troveManager).collateralToken();
        collToken.push(collateralToken);
        collTokenIndex[address(collateralToken)] = collToken.length - 1;
        emit TroveManagerRegistered(_troveManager);
    }

    function removeTroveManager(address _troveManager) external onlyOwner {
        for (uint256 i; i < registeredTroveManagers.length; ++i) {
            if (registeredTroveManagers[i] == _troveManager) {
                delete registeredTroveManagers[i];
                emit TroveManagerRemoved(_troveManager);
                break;
            }
        }
    }

    function setAddresses(address _borrowerOperationsAddress, address _weth, IDebtToken _debtToken) external onlyOwner {
        borrowerOperationsAddress = _borrowerOperationsAddress;
        weth = _weth;
        debtToken = _debtToken;
        emit BorrowerOperationsAddressSet(_borrowerOperationsAddress);
    }

    function transferToken(IERC20 token, address receiver, uint256 amount) external onlyOwner {
        token.safeTransfer(receiver, amount);
    }

    function setTokenApproval(IERC20 token, address spender, uint256 amount) external onlyOwner {
        token.safeApprove(spender, amount);
    }

    // --- Internal Functions ---
    function _updateUserSnapshots(address _user) internal {
        for (uint i; i < collToken.length; ++i) {
            snapshots[_user].F_COLL_Snapshot[i] = F_COLL[i];
        }
        snapshots[_user].F_SAT_Snapshot = F_SAT;
        emit StakerSnapshotsUpdated(_user, F_COLL, F_SAT);
    }

    function _calculateLockWeight(uint256 _amount, LockDuration _duration) internal pure returns (uint256) {
        return _amount * (uint(_duration) + 1);
    }

    function _sendCollToken(IERC20 collateralToken, uint256 collAmount) private {
        if (collAmount == 0) return;

        if (address(collateralToken) == weth) {
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
    function _isCallerBorrowerOperationsOrDebtToken() internal view {
        require(msg.sender == borrowerOperationsAddress || msg.sender == address(debtToken), "RewardManager: Caller is not BorrowerOperations or DebtToken");
    }

    function _isCallerTroveManager() internal view {
        bool isRegistered;
        for (uint256 i; i < registeredTroveManagers.length; ++i) {
            if (msg.sender == registeredTroveManagers[i]) {
                isRegistered = true;
                break;
            }
        }
        require(isRegistered, "RewardManager: Caller is not TroveManager");
    }
}
