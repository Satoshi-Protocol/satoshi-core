// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IWETH} from "../../helpers/interfaces/IWETH.sol";
import {IDebtToken} from "./IDebtToken.sol";

interface IRewardManager is ISatoshiOwnable {
    event TroveManagerRegistered(address);
    event TroveManagerRemoved(address);
    event BorrowerOperationsAddressSet(address);
    event TotalOSHIStakedUpdated(uint256);
    event StakeChanged(address, uint256);
    event StakingGainsWithdrawn(address, uint256[], uint256);
    event StakerSnapshotsUpdated(address, uint256[], uint256);
    event F_COLLUpdated(address, uint256);
    event F_SATUpdated(uint256);

    error NativeTokenTransferFailed();

    enum LockDuration {
        THREE,
        SIX,
        NINE,
        TWELVE
    }

    struct Snapshot {
        uint256[] F_COLL_Snapshot;
        uint256 F_SAT_Snapshot;
    }

    struct Stake {
        address staker;
        uint256 amount;
        LockDuration lockDuration;
        uint32 startTime;
        uint32 endTime;
    }

    struct StakeData {
        uint256 lockWeights;
        uint32 nextUnlockIndex;
    }

    function stake(uint256 _amount, LockDuration _duration) external;
    function unstake(uint256 _amount) external;
    function claimReward() external;
    function increaseCollPerUintStaked(uint256 _amount) external;
    function increaseSATPerUintStaked(uint256 _amount) external;
    function getPendingCollGain(address _user) external view returns (uint256[] memory);
    function getPendingSATGain(address _user) external view returns (uint256);
    function registerTroveManager(address _troveManager) external;
    function removeTroveManager(address _troveManager) external;
    function setAddresses(address _borrowerOperationsAddress, IWETH _weth, IDebtToken _debtToken) external;
    function transferToken(IERC20 token, address receiver, uint256 amount) external;
    function setTokenApproval(IERC20 token, address spender, uint256 amount) external;
}
