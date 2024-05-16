// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISatoshiCore {
    event RewardManagerSet(address rewardManager);
    event FeeReceiverSet(address feeReceiver);
    event GuardianSet(address guardian);
    event NewOwnerAccepted(address oldOwner, address owner);
    event NewOwnerCommitted(address owner, address pendingOwner, uint256 deadline);
    event NewOwnerRevoked(address owner, address revokedOwner);
    event Paused();
    event Unpaused();

    function acceptTransferOwnership() external;

    function commitTransferOwnership(address newOwner) external;

    function revokeTransferOwnership() external;

    function setFeeReceiver(address _feeReceiver) external;

    function setRewardManager(address _rewardManager) external;

    function setGuardian(address _guardian) external;

    function setPaused(bool _paused) external;

    function OWNERSHIP_TRANSFER_DELAY() external view returns (uint256);

    function feeReceiver() external view returns (address);

    function rewardManager() external view returns (address);

    function guardian() external view returns (address);

    function owner() external view returns (address);

    function ownershipTransferDeadline() external view returns (uint256);

    function paused() external view returns (bool);

    function pendingOwner() external view returns (address);

    function startTime() external view returns (uint256);
}
