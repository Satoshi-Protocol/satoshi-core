// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";

interface ITroveHelper {
    function getNicrByTime(ITroveManager troveManager, address _borrower, uint256 time)
        external
        view
        returns (uint256);

    function getNicrListByTime(ITroveManager troveManager, address[] memory _borrower, uint256 time)
        external
        view
        returns (uint256[] memory);

    function calculateInterestIndexByTime(ITroveManager troveManager, uint256 time)
        external
        view
        returns (uint256 currentInterestIndex, uint256 interestFactor);

    function getTroveCollAndDebtByTime(ITroveManager troveManager, address _borrower, uint256 time)
        external
        view
        returns (uint256 coll, uint256 debt);

    // SortedTroves
    function getNode(address sortedTrovesAddress, address _borrower)
        external
        view
        returns (bool exist, address nextId, address prevId);
}
