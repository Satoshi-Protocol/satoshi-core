// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IFactory} from "../interfaces/core/IFactory.sol";
import {ITroveHelper} from "./interfaces/ITroveHelper.sol";
import {ISortedTroves} from "../interfaces/core/ISortedTroves.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";

contract TroveHelper is ITroveHelper {
    uint256 constant INTEREST_PRECISION = 1e27;

    constructor() {}

    function getNicrByTime(ITroveManager troveManager, address _borrower, uint256 time) public view returns (uint256) {
        require(time >= block.timestamp, "TroveHelper: invalid time");
        (uint256 currentCollateral, uint256 currentDebt) = getTroveCollAndDebtByTime(troveManager, _borrower, time);
        uint256 NICR = SatoshiMath._computeNominalCR(currentCollateral, currentDebt);

        return NICR;
    }

    function getNicrListByTime(ITroveManager troveManager, address[] memory _borrower, uint256 time)
        external
        view
        returns (uint256[] memory)
    {
        require(time >= block.timestamp, "TroveHelper: invalid time");
        uint256[] memory nicrList = new uint256[](_borrower.length);
        for (uint256 i; i < _borrower.length; ++i) {
            nicrList[i] = getNicrByTime(troveManager, _borrower[i], time);
        }

        return nicrList;
    }

    function calculateInterestIndexByTime(ITroveManager troveManager, uint256 time)
        external
        view
        returns (uint256 currentInterestIndex, uint256 interestFactor)
    {
        require(time >= block.timestamp, "TroveHelper: invalid time");
        (currentInterestIndex, interestFactor) = _calculateInterestIndex(troveManager, time);
    }

    // SortedTroves
    function getNode(address sortedTrovesAddress, address _borrower)
        external
        view
        returns (bool exist, address nextId, address prevId)
    {
        ISortedTroves sortedTroves = ISortedTroves(sortedTrovesAddress);
        // check if the trove exists
        exist = sortedTroves.contains(_borrower);
        if (exist) {
            nextId = sortedTroves.getNext(_borrower);
            prevId = sortedTroves.getPrev(_borrower);
        }
    }

    function getTroveCollAndDebtByTime(ITroveManager troveManager, address _borrower, uint256 time)
        public
        view
        returns (uint256, uint256)
    {
        require(time >= block.timestamp, "TroveHelper: invalid time");
        (uint256 debt, uint256 coll,,,, uint256 activeInterestIndex) = troveManager.troves(_borrower);

        (uint256 pendingCollateralReward, uint256 pendingDebtReward) =
            troveManager.getPendingCollAndDebtRewards(_borrower);
        // Accrued trove interest for correct liquidation values. This assumes the index to be updated.
        uint256 troveInterestIndex = activeInterestIndex;
        if (troveInterestIndex > 0) {
            (uint256 currentIndex,) = _calculateInterestIndex(troveManager, time);
            debt = (debt * currentIndex) / troveInterestIndex;
        }

        debt = debt + pendingDebtReward;
        coll = coll + pendingCollateralReward;

        return (coll, debt);
    }

    // --- internal functions ---

    function _calculateInterestIndex(ITroveManager troveManager, uint256 time)
        internal
        view
        returns (uint256 currentInterestIndex, uint256 interestFactor)
    {
        uint256 lastIndexUpdateCached = troveManager.lastActiveIndexUpdate();
        require(time >= lastIndexUpdateCached, "TroveHelper: invalid time");
        uint256 activeInterestIndex = troveManager.activeInterestIndex();
        uint256 currentInterest = troveManager.interestRate();
        currentInterestIndex = activeInterestIndex; // we need to return this if it's already up to date
        if (currentInterest > 0) {
            /*
                * Calculate the interest accumulated and the new index:
                * We compound the index and increase the debt accordingly
                */
            uint256 deltaT = time - lastIndexUpdateCached;
            interestFactor = deltaT * currentInterest;
            currentInterestIndex =
                currentInterestIndex + Math.mulDiv(currentInterestIndex, interestFactor, INTEREST_PRECISION);
        }
    }
}
