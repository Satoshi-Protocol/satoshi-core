// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {DeploymentParams} from "../src/interfaces/core/IFactory.sol";
import {TroveHelper} from "../src/helpers/TroveHelper.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    MINUTE_DECAY_FACTOR,
    REDEMPTION_FEE_FLOOR,
    MAX_REDEMPTION_FEE,
    BORROWING_FEE_FLOOR,
    MAX_BORROWING_FEE,
    INTEREST_RATE_IN_BPS,
    MAX_DEBT,
    MCR,
    REWARD_RATE,
    TM_ALLOCATION,
    TM_CLAIM_START_TIME
} from "../script/DeployInstanceConfig.sol";

contract TMSetParamters is Test {
    ITroveManager troveManager = ITroveManager(0xf1A7b474440702BC32F622291B3A01B80247835E);
    address constant owner = 0xD17FF2e991616BC759981152B8E5B57c8Fddb15C;
    IMultiCollateralHintHelpers hintHelpers = IMultiCollateralHintHelpers(0x96173C9319A1A52C94bC99C6401bDDC28BAc132c);
    ISortedTroves sortedTrovesBeaconProxy = ISortedTroves(0x49B0050fFA9a3e1033c1c8d963665F3ad0716eE4);
    ISatoshiPeriphery satoshiPeriphery = ISatoshiPeriphery(0x95d4adBd1aD72B7c00565B241313c363EC68cA73);
    IERC20 SAT = IERC20(0xa1e63CB2CE698CfD3c2Ac6704813e3b870FEDADf);
    DeploymentParams internal params;
    address constant _borrower = 0xc47A90C57577d46Edf788Ad15eD79A69969b6F7F;

    function setUp() public {
        vm.createSelectFork("https://rpc.bitlayer.org");
        params = DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: 0,
            maxDebt: MAX_DEBT,
            MCR: MCR,
            rewardRate: REWARD_RATE,
            OSHIAllocation: TM_ALLOCATION,
            claimStartTime: TM_CLAIM_START_TIME
        });
        vm.startPrank(owner);
        troveManager.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR,
            params.rewardRate,
            params.claimStartTime
        );
        vm.stopPrank();

        vm.label(address(satoshiPeriphery), "satoshiPeriphery");
    }

    function test_checkDebtNotIncrease() public {
        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(collBefore, collAfter);
        assertEq(debtBefore, debtAfter);
    }

    function test_addCollSuccess() public {
        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        uint256 addAmount = 100000000;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManager, collBefore + addAmount, debtBefore, 0.05e18
        );

        vm.prank(_borrower);
        // tx execution
        satoshiPeriphery.addColl{value: addAmount}(troveManager, addAmount, upperHint, lowerHint);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(collBefore + addAmount, collAfter);
        assertEq(debtBefore, debtAfter);
    }

    function test_withdrawColl() public {
        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        uint256 withdrawAmount = 100;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManager, collBefore - withdrawAmount, debtBefore, 0.05e18
        );

        vm.prank(_borrower);
        // tx execution
        satoshiPeriphery.withdrawColl(troveManager, withdrawAmount, upperHint, lowerHint);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(collBefore - withdrawAmount, collAfter);
        assertEq(debtBefore, debtAfter);
    }

    function test_withdrawDebt() public {
        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        uint256 withdrawAmount = 100;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManager, collBefore, debtBefore + withdrawAmount, 0.05e18
        );

        vm.prank(_borrower);
        // tx execution
        satoshiPeriphery.withdrawDebt(troveManager, 0.05e18, withdrawAmount, upperHint, lowerHint);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(collBefore, collAfter);
        assertEq(debtBefore + withdrawAmount, debtAfter);
    }

    function test_repayDebt() public {
        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        uint256 repayAmount = 100;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManager, collBefore, debtBefore - repayAmount, 0.05e18
        );

        vm.startPrank(_borrower);
        SAT.approve(address(satoshiPeriphery), repayAmount);
        // tx execution
        satoshiPeriphery.repayDebt(troveManager, repayAmount, upperHint, lowerHint);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(collBefore, collAfter);
        assertEq(debtBefore - repayAmount, debtAfter);

        vm.stopPrank();
    }

    function test_closeTrove() public {
        (, uint256 debtBefore) = troveManager.getTroveCollAndDebt(_borrower);

        address whale = 0x575212A8763db6Bbaf67461440246546D4017707;
        vm.prank(whale);
        SAT.transfer(_borrower, debtBefore);

        vm.startPrank(_borrower);
        SAT.approve(address(satoshiPeriphery), debtBefore);
        // tx execution
        satoshiPeriphery.closeTrove(troveManager);

        vm.warp(block.timestamp + 1 days);

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(_borrower);

        assertEq(0, collAfter);
        assertEq(0, debtAfter);

        vm.stopPrank();
    }
}
