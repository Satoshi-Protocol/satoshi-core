// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {PrismaMath} from "../src/dependencies/PrismaMath.sol";
import {DeployBase} from "./DeployBase.t.sol";
import {TestConfig} from "./TestConfig.sol";

abstract contract HintHelpers {
    using Math for uint256;

    uint256 internal constant TRIAL_NUMBER = 15;
    uint256 internal constant RANDOM_SEED = 42;

    function _getHint(
        MultiCollateralHintHelpers hintHelpers,
        ISortedTroves sortedTrovesBeaconProxy,
        ITroveManager troveManagerBeaconProxy,
        uint256 collateralAmt,
        uint256 debtAmt,
        uint256 gasCompensation
    ) internal view returns (address, address) {
        uint256 expectedFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(debtAmt);
        uint256 expectedDebt = debtAmt + expectedFee + gasCompensation;
        uint256 NICR = collateralAmt.mulDiv(PrismaMath.NICR_PRECISION, expectedDebt);
        uint256 numTroves = sortedTrovesBeaconProxy.getSize();
        uint256 numTrials = numTroves * TRIAL_NUMBER;
        (address approxHint,,) = hintHelpers.getApproxHint(troveManagerBeaconProxy, NICR, numTrials, RANDOM_SEED);
        (address upperHint, address lowerHint) =
            sortedTrovesBeaconProxy.findInsertPosition(NICR, approxHint, approxHint);

        return (upperHint, lowerHint);
    }
}
