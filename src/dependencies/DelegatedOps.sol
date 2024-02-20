// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IDelegatedOps} from "../interfaces/dependencies/IDelegatedOps.sol";

/**
 * @title Delegated Operations Contract
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/dependencies/DelegatedOps.sol
 *
 */
abstract contract DelegatedOps is IDelegatedOps {
    // owner => caller => isApproved
    mapping(address => mapping(address => bool)) public isApprovedDelegate;

    modifier callerOrDelegated(address _account) {
        require(msg.sender == _account || isApprovedDelegate[_account][msg.sender], "Delegate not approved");
        _;
    }

    function setDelegateApproval(address _delegate, bool _isApproved) external {
        isApprovedDelegate[msg.sender][_delegate] = _isApproved;
        emit DelegateApprovalSet(msg.sender, _delegate, _isApproved);
    }
}
