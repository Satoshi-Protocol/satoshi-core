// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";
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

struct TMParams {
    uint256 getEntireSystemColl;
    uint256 getEntireSystemDebt;
    uint256 price;
}

contract MCRSettingTest is Test {
    ITroveManager troveManager = ITroveManager(0xf1A7b474440702BC32F622291B3A01B80247835E);
    address constant owner = 0xD17FF2e991616BC759981152B8E5B57c8Fddb15C;
    IMultiCollateralHintHelpers hintHelpers = IMultiCollateralHintHelpers(0x96173C9319A1A52C94bC99C6401bDDC28BAc132c);
    ISortedTroves sortedTrovesBeaconProxy = ISortedTroves(0x49B0050fFA9a3e1033c1c8d963665F3ad0716eE4);
    ISatoshiPeriphery satoshiPeriphery = ISatoshiPeriphery(0x95d4adBd1aD72B7c00565B241313c363EC68cA73);
    IERC20 SAT = IERC20(0xa1e63CB2CE698CfD3c2Ac6704813e3b870FEDADf);
    ILiquidationManager liquidationManager = ILiquidationManager(0x802fC8764Ef4C700B9910993fc72624f7CAd2681);
    DeploymentParams internal params;

    function setUp() public {
        vm.createSelectFork(vm.envString("BITLAYER_RPC_URL"));
    }

    function test_troveDataRemainSame() public {
        TMParams memory tmParams;

        tmParams.getEntireSystemColl = troveManager.getEntireSystemColl();
        tmParams.getEntireSystemDebt = troveManager.getEntireSystemDebt();
        tmParams.price = troveManager.fetchPrice();

        address account = sortedTrovesBeaconProxy.getLast();

        (uint256 collBefore, uint256 debtBefore) = troveManager.getTroveCollAndDebt(account);

        params = DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: 0,
            maxDebt: MAX_DEBT,
            MCR: 12 * 1e17, // 120%
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

        (uint256 collAfter, uint256 debtAfter) = troveManager.getTroveCollAndDebt(account);

        assertEq(collBefore, collAfter);
        assertEq(debtBefore, debtAfter);
        assertEq(params.MCR, troveManager.MCR());
        assertEq(tmParams.getEntireSystemColl, troveManager.getEntireSystemColl());
        assertEq(tmParams.getEntireSystemDebt, troveManager.getEntireSystemDebt());

        // account should not be liquidated
        vm.expectRevert("TroveManager: nothing to liquidate");
        liquidationManager.liquidate(troveManager, account);

        uint256 maxBorrow = collBefore * tmParams.price * 100 / 120 / 1e18;
        uint256 withdrawAmount = maxBorrow - debtBefore + 1e18;

        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManager, collBefore, debtBefore + withdrawAmount, 0.05e18
        );

        vm.startPrank(account);
        vm.expectRevert("BorrowerOps: An operation that would result in ICR < MCR is not permitted");
        satoshiPeriphery.withdrawDebt(troveManager, 0.05e18, withdrawAmount, upperHint, lowerHint);
    }
}
