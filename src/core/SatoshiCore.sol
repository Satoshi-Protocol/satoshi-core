// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";

/**
 * @title SatoshiCore Contract (Non-upgradeable)
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/PrismaCore.sol
 *
 *        Core contract to control the roles and permissions of the protocol
 */
contract SatoshiCore is ISatoshiCore {
    address public feeReceiver;
    address public rewardManager;

    address public owner;
    address public pendingOwner;
    uint256 public ownershipTransferDeadline;

    address public guardian;

    // We enforce a three day delay between committing and applying
    // an ownership change, as a sanity check on a proposed new owner
    // and to give users time to react in case the act is malicious.
    uint256 public constant OWNERSHIP_TRANSFER_DELAY = 86400 * 3;

    // System-wide pause. When true, disables trove adjustments across all collaterals.
    bool public paused;

    // System-wide start time.
    // Other contracts that require access to this should inherit `SystemStart`.
    uint256 public immutable startTime;

    constructor(address _owner, address _guardian, address _feeReceiver, address _rewardManager) {
        owner = _owner;
        startTime = block.timestamp;
        guardian = _guardian;
        feeReceiver = _feeReceiver;
        rewardManager = _rewardManager;
        emit GuardianSet(_guardian);
        emit FeeReceiverSet(_feeReceiver);
        emit RewardManagerSet(_rewardManager);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    /**
     * @notice Set the receiver of one time borrow fee in the protocol
     * @param _feeReceiver Address of the fee's recipient
     */
    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
        emit FeeReceiverSet(_feeReceiver);
    }

    /**
     * @notice Set the guardian address
     *            The guardian can execute some emergency actions
     * @param _guardian Guardian address
     */
    function setGuardian(address _guardian) external onlyOwner {
        guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    /**
     * @notice Set the reward manager address
     * @param _rewardManager Reward manager address
     */
    function setRewardManager(address _rewardManager) external onlyOwner {
        rewardManager = _rewardManager;
        emit RewardManagerSet(rewardManager);
    }

    /**
     * @notice Sets the global pause state of the protocol
     *         Pausing is used to mitigate risks in exceptional circumstances
     *         Functionalities affected by pausing are:
     *         - New borrowing is not possible
     *         - New collateral deposits are not possible
     *         - New stability pool deposits are not possible
     * @param _paused If true the protocol is paused
     */
    function setPaused(bool _paused) external {
        require((_paused && msg.sender == guardian) || msg.sender == owner, "Unauthorized");
        paused = _paused;
        if (_paused) {
            emit Paused();
        } else {
            emit Unpaused();
        }
    }

    function commitTransferOwnership(address newOwner) external onlyOwner {
        pendingOwner = newOwner;
        ownershipTransferDeadline = block.timestamp + OWNERSHIP_TRANSFER_DELAY;

        emit NewOwnerCommitted(msg.sender, newOwner, block.timestamp + OWNERSHIP_TRANSFER_DELAY);
    }

    function acceptTransferOwnership() external {
        require(msg.sender == pendingOwner, "Only new owner");
        require(block.timestamp >= ownershipTransferDeadline, "Deadline not passed");

        emit NewOwnerAccepted(owner, msg.sender);

        owner = pendingOwner;
        pendingOwner = address(0);
        ownershipTransferDeadline = 0;
    }

    function revokeTransferOwnership() external onlyOwner {
        emit NewOwnerRevoked(msg.sender, pendingOwner);

        pendingOwner = address(0);
        ownershipTransferDeadline = 0;
    }
}
