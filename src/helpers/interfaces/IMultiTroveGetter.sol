// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";

struct CombinedTroveData {
    address owner;
    uint256 debt;
    uint256 coll;
    uint256 stake;
    uint256 snapshotCollateral;
    uint256 snapshotDebt;
}

interface IMultiTroveGetter {
    function getMultipleSortedTroves(ITroveManager troveManager, int256 _startIdx, uint256 _count)
        external
        view
        returns (CombinedTroveData[] memory _troves);
}
