// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDelegatedOps {
    event DelegateApprovalSet(address indexed caller, address indexed delegate, bool isApproved);

    function isApprovedDelegate(address _account, address _delegate) external view returns (bool);

    function setDelegateApproval(address _delegate, bool _isApproved) external;
}
