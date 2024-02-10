// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IBorrowerOperations} from "../../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";
import {ISatoshiBase} from "../../interfaces/dependencies/ISatoshiBase.sol";

interface IMultiCollateralHintHelpers is ISatoshiBase {
    function borrowerOperations() external view returns (IBorrowerOperations);

    function getRedemptionHints(ITroveManager troveManager, uint256 _debtAmount, uint256 _price, uint256 _maxIterations)
        external
        view
        returns (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount);

    function getApproxHint(ITroveManager troveManager, uint256 _CR, uint256 _numTrials, uint256 _inputRandomSeed)
        external
        view
        returns (address hintAddress, uint256 diff, uint256 latestRandomSeed);

    function computeNominalCR(uint256 _coll, uint256 _debt) external pure returns (uint256);

    function computeCR(uint256 _coll, uint256 _debt, uint256 _price) external pure returns (uint256);
}
