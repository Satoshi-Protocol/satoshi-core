// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {ISortedTroves} from "../interfaces/core/ISortedTroves.sol";
import {IMultiTroveGetter, CombinedTroveData} from "./interfaces/IMultiTroveGetter.sol";

/**
 * @title Multiple Trove Getter Contract
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/helpers/MultiTroveGetter.sol
 *
 */
contract MultiTroveGetter is IMultiTroveGetter {
    constructor() {}

    function getMultipleSortedTroves(ITroveManager troveManager, int256 _startIdx, uint256 _count)
        external
        view
        returns (CombinedTroveData[] memory _troves)
    {
        ISortedTroves sortedTroves = ISortedTroves(troveManager.sortedTroves());
        uint256 startIdx;
        bool descend;

        if (_startIdx >= 0) {
            startIdx = uint256(_startIdx);
            descend = true;
        } else {
            startIdx = uint256(-(_startIdx + 1));
            descend = false;
        }

        uint256 sortedTrovesSize = sortedTroves.getSize();

        if (startIdx >= sortedTrovesSize) {
            _troves = new CombinedTroveData[](0);
        } else {
            uint256 maxCount = sortedTrovesSize - startIdx;

            if (_count > maxCount) {
                _count = maxCount;
            }

            if (descend) {
                _troves = _getMultipleSortedTrovesFromHead(troveManager, sortedTroves, startIdx, _count);
            } else {
                _troves = _getMultipleSortedTrovesFromTail(troveManager, sortedTroves, startIdx, _count);
            }
        }
    }

    function _getMultipleSortedTrovesFromHead(
        ITroveManager troveManager,
        ISortedTroves sortedTroves,
        uint256 _startIdx,
        uint256 _count
    ) internal view returns (CombinedTroveData[] memory _troves) {
        address currentTroveowner = sortedTroves.getFirst();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getNext(currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _troves[idx].owner = currentTroveowner;
            (
                _troves[idx].debt,
                _troves[idx].coll,
                _troves[idx].stake,
                /* status */
                /* arrayIndex */
                /* interestIndex */
                ,
                ,
            ) = troveManager.troves(currentTroveowner);
            (_troves[idx].snapshotCollateral, _troves[idx].snapshotDebt) =
                troveManager.rewardSnapshots(currentTroveowner);

            currentTroveowner = sortedTroves.getNext(currentTroveowner);
        }
    }

    function _getMultipleSortedTrovesFromTail(
        ITroveManager troveManager,
        ISortedTroves sortedTroves,
        uint256 _startIdx,
        uint256 _count
    ) internal view returns (CombinedTroveData[] memory _troves) {
        address currentTroveowner = sortedTroves.getLast();

        for (uint256 idx = 0; idx < _startIdx; ++idx) {
            currentTroveowner = sortedTroves.getPrev(currentTroveowner);
        }

        _troves = new CombinedTroveData[](_count);

        for (uint256 idx = 0; idx < _count; ++idx) {
            _troves[idx].owner = currentTroveowner;
            (
                _troves[idx].debt,
                _troves[idx].coll,
                _troves[idx].stake,
                /* status */
                /* arrayIndex */
                /* interestIndex */
                ,
                ,
            ) = troveManager.troves(currentTroveowner);
            (_troves[idx].snapshotCollateral, _troves[idx].snapshotDebt) =
                troveManager.rewardSnapshots(currentTroveowner);

            currentTroveowner = sortedTroves.getPrev(currentTroveowner);
        }
    }
}
