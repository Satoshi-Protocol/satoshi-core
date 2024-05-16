// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";

struct CombinedTroveData {
    address owner;
    uint256 debt;
    uint256 coll;
    uint256 stake;
    uint256 snapshotCollateral;
    uint256 snapshotDebt;
    uint256 nominalICR;
    uint256 currentICR;
    uint256 entireDebt;
    uint256 entireColl;
    uint256 pendingDebtReward;
    uint256 pendingCollReward;
}

interface IMultiTroveGetter {
    function getMultipleSortedTroves(ITroveManager troveManager, int256 _startIdx, uint256 _count, uint256 price)
        external
        view
        returns (CombinedTroveData[] memory _troves);
}
