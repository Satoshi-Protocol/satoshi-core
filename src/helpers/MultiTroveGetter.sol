// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

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

    function getMultipleSortedTroves(ITroveManager troveManager, int256 _startIdx, uint256 _count, uint256 price)
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
                _troves = _getMultipleSortedTrovesFromHead(troveManager, sortedTroves, startIdx, _count, price);
            } else {
                _troves = _getMultipleSortedTrovesFromTail(troveManager, sortedTroves, startIdx, _count, price);
            }
        }
    }

    function _getMultipleSortedTrovesFromHead(
        ITroveManager troveManager,
        ISortedTroves sortedTroves,
        uint256 _startIdx,
        uint256 _count,
        uint256 price
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

            _troves[idx].nominalICR = troveManager.getNominalICR(currentTroveowner);
            _troves[idx].currentICR = troveManager.getCurrentICR(currentTroveowner, price);

            (
                _troves[idx].entireDebt,
                _troves[idx].entireColl,
                _troves[idx].pendingDebtReward,
                _troves[idx].pendingCollReward
            ) = troveManager.getEntireDebtAndColl(currentTroveowner);

            currentTroveowner = sortedTroves.getNext(currentTroveowner);
        }
    }

    function _getMultipleSortedTrovesFromTail(
        ITroveManager troveManager,
        ISortedTroves sortedTroves,
        uint256 _startIdx,
        uint256 _count,
        uint256 price
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

            _troves[idx].nominalICR = troveManager.getNominalICR(currentTroveowner);
            _troves[idx].currentICR = troveManager.getCurrentICR(currentTroveowner, price);

            (
                _troves[idx].entireDebt,
                _troves[idx].entireColl,
                _troves[idx].pendingDebtReward,
                _troves[idx].pendingCollReward
            ) = troveManager.getEntireDebtAndColl(currentTroveowner);

            currentTroveowner = sortedTroves.getPrev(currentTroveowner);
        }
    }
}
