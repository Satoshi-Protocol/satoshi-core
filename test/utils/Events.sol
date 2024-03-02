// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TroveManagerOperation} from "../../src/interfaces/core/ITroveManager.sol";

///NOTE: Copied events from the core contracts for testing
abstract contract Events {
    // BorrowerOperations
    event BorrowingFeePaid(address indexed borrower, IERC20 indexed collateralToken, uint256 amount);

    // SortedTroves
    event NodeAdded(address _id, uint256 _NICR);
    event NodeRemoved(address _id);

    // TroveManager
    event TroveUpdated(
        address indexed _borrower, uint256 _debt, uint256 _coll, uint256 _stake, TroveManagerOperation _operation
    );
    event TotalStakesUpdated(uint256 _newTotalStakes);

    // ReferralManager
    event ExecuteReferral(address indexed borrower, address indexed referrer, uint256 points);
}
