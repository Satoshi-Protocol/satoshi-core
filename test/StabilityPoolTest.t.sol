// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, _1_MILLION} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";

contract StabilityPoolTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 0.05e18; // 5%

    struct StabilityPoolVars {
        uint256 collGainBefore;
        uint256 collGainAfter;
        uint256 stakeBefore;
        uint256 stakeAfter;
        uint256 stabilityPoolDebtBefore;
        uint256 stabilityPoolDebtAfter;
        uint256 PBefore;
        uint256 SBefore;
        uint256 GBefore;
        uint256 OSHIBefore;
        uint256 OSHIAfter;
        // user state
        uint256[4] userCollBefore;
        uint256[4] userCollAfter;
        uint256[4] userDebtBefore;
        uint256[4] userDebtAfter;
    }

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
    }

    // utils
    function _openTrove(address caller, uint256 collateralAmt, uint256 debtAmt) internal {
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            caller,
            caller,
            collateralMock,
            collateralAmt,
            debtAmt,
            maxFeePercentage
        );
    }

    function _provideToSP(address caller, uint256 amount) internal {
        TroveBase.provideToSP(stabilityPoolProxy, caller, amount);
    }

    function _withdrawFromSP(address caller, uint256 amount) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy, caller, amount);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _claimCollateralGains(address caller) internal {
        vm.startPrank(caller);
        uint256[] memory collateralIndexes = new uint256[](1);
        collateralIndexes[0] = 0;
        stabilityPoolProxy.claimCollateralGains(caller, collateralIndexes);
        vm.stopPrank();
    }

    function _claimOSHIReward(address caller) internal {
        vm.startPrank(caller);
        stabilityPoolProxy.claimReward(caller);
        vm.stopPrank();
    }

    function _recordUserStateBeforeToVar(StabilityPoolVars memory vars) internal view {
        (vars.userCollBefore[0], vars.userDebtBefore[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollBefore[1], vars.userDebtBefore[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollBefore[2], vars.userDebtBefore[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollBefore[3], vars.userDebtBefore[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
    }

    function _recordUserStateAfterToVar(StabilityPoolVars memory vars) internal view {
        (vars.userCollAfter[0], vars.userDebtAfter[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollAfter[1], vars.userDebtAfter[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollAfter[2], vars.userDebtAfter[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollAfter[3], vars.userDebtAfter[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
    }

    // deposit to SP and check the stake amount in SP
    function testProvideToSP() public {
        StabilityPoolVars memory vars;
        // open trove
        _openTrove(user1, 1e18, 10000e18);
        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtBefore, 0);

        // deposit to SP
        _provideToSP(user1, 200e18);
        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtAfter, 200e18);
    }

    // withdraw from SP and check the stake amount in SP
    function testWithdrawFromSPFull() public {
        StabilityPoolVars memory vars;
        // open trove
        _openTrove(user1, 1e18, 10000e18);

        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtBefore, 0);

        // deposit to SP
        _provideToSP(user1, 200e18);

        vm.warp(block.timestamp + 1);

        // withdraw from SP
        _withdrawFromSP(user1, 200e18);
        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtAfter, 0);
    }

    function testLiquidateInNormalModeICRLessThanMCR() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        _recordUserStateBeforeToVar(vars);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 20500
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        // check user2 and user3's Troves are liquidated (Troves are closed)
        assertFalse(sortedTrovesBeaconProxy.contains(user2));
        assertFalse(sortedTrovesBeaconProxy.contains(user3));

        // Confirm SP has decreased
        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertTrue(vars.stabilityPoolDebtAfter < vars.stabilityPoolDebtBefore);
        assertEq(
            vars.stabilityPoolDebtAfter, vars.stabilityPoolDebtBefore - vars.userDebtBefore[1] - vars.userDebtBefore[2]
        );

        // check the collateral gain by user1
        // vars.collGainBefore = stabilityPoolProxy.getDepositorCollateralGain(user1)[0];
        // console.log("collGainBefore: ", vars.collGainBefore);
        // console.log((user2CollBefore + user3CollBefore) * 995 / 1000);
        // assertEq(vars.collGainBefore, (user2CollBefore + user3CollBefore) * 995 / 1000);
    }

    function testLiquidateInNormalModeICRLessThan100() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        _recordUserStateBeforeToVar(vars);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 10000_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();

        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        // check user2 and user3's Troves are liquidated (Troves are closed)
        assertFalse(sortedTrovesBeaconProxy.contains(user2));
        assertFalse(sortedTrovesBeaconProxy.contains(user3));

        // Confirm SP has decreased
        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertTrue(vars.stabilityPoolDebtAfter < vars.stabilityPoolDebtBefore);
        assertEq(
            vars.stabilityPoolDebtAfter, vars.stabilityPoolDebtBefore - vars.userDebtBefore[1] - vars.userDebtBefore[2]
        );
    }

    function testCorrectUpdateSnapshot() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        _openTrove(user4, 1e18, 100e18);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 20500
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        vars.PBefore = stabilityPoolProxy.P();
        vars.SBefore = stabilityPoolProxy.epochToScaleToSums(0, 0, 0);
        vars.GBefore = stabilityPoolProxy.epochToScaleToG(0, 0);
        assertTrue(vars.PBefore > 0);
        assertTrue(vars.SBefore > 0);

        // user4 before snapshot
        (uint256 user4PBefore, uint256 user4GBefore,,) = stabilityPoolProxy.depositSnapshots(user4);
        assertEq(user4PBefore, 0);
        assertEq(user4GBefore, 0);

        // user4 deposit
        _provideToSP(user4, 100e18);

        // user4 after snapshot
        (uint256 user4PAfter, uint256 user4GAfter,,) = stabilityPoolProxy.depositSnapshots(user4);
        assertEq(user4PAfter, vars.PBefore);
        assertEq(user4GAfter, vars.GBefore);
    }

    function testTryToProvideMoreThanBlanace() public {
        _openTrove(user1, 1e18, 100e18);

        // attempt to provide 1 wei more than his balance
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        TroveBase.provideToSP(stabilityPoolProxy, user1, 100e18 + 1);
    }

    function testTryToProvide0Blanace() public {
        _openTrove(user1, 1e18, 100e18);

        // attempt to provide 0 balance
        vm.expectRevert("StabilityPool: Amount must be non-zero");
        TroveBase.provideToSP(stabilityPoolProxy, user1, 0);
    }

    function testClaimCollGain() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 10000e18, 185000e18);
        // 1 tove opened
        _openTrove(user2, 1e18, 20000e18);
        // user3 opens trove
        _openTrove(user3, 1e18, 20000e18);

        _provideToSP(user1, 70000e18);
        _provideToSP(user2, 20000e18);

        _recordUserStateBeforeToVar(vars);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20000_00_000_000, // 20000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        // liquidate user2
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        // check user2 trove is liquidated
        assertFalse(sortedTrovesBeaconProxy.contains(user2));

        vars.collGainBefore = stabilityPoolProxy.getDepositorCollateralGain(user2)[0];
        assert(vars.collGainBefore > 0);

        // user2 claim collateral gain
        _claimCollateralGains(user2);

        // check the collateral gain is as expected
        assertEq(vars.collGainBefore, collateralMock.balanceOf(user2));

        // check the gain is 0 after claiming
        vars.collGainAfter = stabilityPoolProxy.getDepositorCollateralGain(user2)[0];
        assertEq(vars.collGainAfter, 0);

        // liqidate user3
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);
        // check user3 trove is liquidated
        assertFalse(sortedTrovesBeaconProxy.contains(user3));

        vars.collGainAfter = stabilityPoolProxy.getDepositorCollateralGain(user2)[0];
        assertApproxEqAbs(vars.collGainBefore, vars.collGainAfter, 10000);

        _recordUserStateAfterToVar(vars);
        // check user1 trove reamins the same
        assertEq(vars.userCollBefore[0], vars.userCollAfter[0]);
        assertEq(vars.userDebtBefore[0], vars.userDebtAfter[0]);

        // user2 claim collateral gain
        _claimCollateralGains(user2);

        // check the gain is 0 after claiming
        vars.collGainAfter = stabilityPoolProxy.getDepositorCollateralGain(user2)[0];
        assertEq(vars.collGainAfter, 0);
    }

    function testCompoundedDebt() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 10000e18, 185000e18);
        _provideToSP(user1, 20000e18);
        // 1 tove opened
        _openTrove(user2, 1e18, 20000e18);
        _provideToSP(user2, 20000e18);
        // user3 opens trove
        _openTrove(user3, 1e18, 20000e18);

        _recordUserStateBeforeToVar(vars);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't (normal mode)
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        // user1 get the compounded debt after
        vars.stakeBefore = stabilityPoolProxy.getCompoundedDebtDeposit(user1);
        assertEq(vars.stakeBefore, 20000e18);

        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        // liquidate user2
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);

        _claimCollateralGains(user1);

        // user1 get the compounded debt after
        vars.stakeAfter = stabilityPoolProxy.getCompoundedDebtDeposit(user1);
        assert(vars.stakeAfter < vars.stakeBefore);
        assertTrue(
            SatoshiMath._approximatelyEqual(vars.stakeAfter, vars.stakeBefore - vars.userDebtBefore[1] / 2, 100000)
        );

        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtAfter, vars.stabilityPoolDebtBefore - vars.userDebtBefore[1]);

        // liquidate user3 -> SP is empty
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        assertEq(stabilityPoolProxy.getCompoundedDebtDeposit(user1), 0);
        assertEq(stabilityPoolProxy.getCompoundedDebtDeposit(user2), 0);
        assertEq(stabilityPoolProxy.getTotalDebtTokenDeposits(), 0);

        // try to withdraw from SP
        vm.warp(block.timestamp + 1);
        assertEq(debtToken.balanceOf(user2), 0);
        _withdrawFromSP(user2, 1e18);
        assertEq(debtToken.balanceOf(user2), 0);
    }

    function test_2lquidateAndProvide() public {
        StabilityPoolVars memory vars;
        // whale opens trove
        _openTrove(user1, 10000e18, 185000e18);
        // 1 tove opened
        _openTrove(user2, 1e18, 20000e18);
        // user3 opens trove
        _openTrove(user3, 1e18, 20000e18);

        // provide to SP
        _provideToSP(user1, 50000e18);
        _provideToSP(user2, 10000e18);

        _recordUserStateBeforeToVar(vars);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't (normal mode)
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        // liquidate user2
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);

        _claimCollateralGains(user2);

        // liquidate user3
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        _claimCollateralGains(user2);

        // provide to SP
        uint256 provideAmt = 10000e18;
        _provideToSP(user2, provideAmt);

        // check the stake amount in SP
        vars.stakeAfter = stabilityPoolProxy.getCompoundedDebtDeposit(user2);
        uint256 expectedStake = 2 * provideAmt - (vars.userDebtBefore[1] + vars.userDebtBefore[2]) / 6;
        assertTrue(SatoshiMath._approximatelyEqual(vars.stakeAfter, expectedStake, 10000));
    }

    // deposit to SP and check the stake amount in SP
    function testOSHIEmissionWhenEmissionEnd() public {
        StabilityPoolVars memory vars;
        // open trove
        _openTrove(user1, 1e18, 10000e18);
        vars.stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtBefore, 0);

        // deposit to SP
        _provideToSP(user1, 200e18);
        vars.stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(vars.stabilityPoolDebtAfter, 200e18);
        // 5 years later
        vm.warp(block.timestamp + 365 days * 6);
        uint256 oshiReward = stabilityPoolProxy.claimableReward(user1);
        _claimOSHIReward(user1);
        vars.OSHIBefore = oshiToken.balanceOf(user1);
        assertEq(oshiReward, 10 * _1_MILLION);
        assertEq(vars.OSHIBefore, oshiReward);
    }

    function test_setRewardrate() public {
        vm.prank(OWNER);
        stabilityPoolProxy.setRewardRate(0);

        _openTrove(user1, 1e18, 1000e18);
        _provideToSP(user1, 1000e18);
        // check no oshi reward in SP
        assertEq(stabilityPoolProxy.claimableReward(user1), 0);
        vm.warp(block.timestamp + 10000);
        assertEq(stabilityPoolProxy.claimableReward(user1), 0);

        vm.startPrank(OWNER);
        stabilityPoolProxy.setRewardRate(stabilityPoolProxy.MAX_REWARD_RATE());
        vm.stopPrank();
        assertEq(stabilityPoolProxy.rewardRate(), stabilityPoolProxy.MAX_REWARD_RATE());

        vm.warp(block.timestamp + 10000);
        // check oshi reward in SP
        uint256 rewardRate = stabilityPoolProxy.rewardRate();
        assertEq(stabilityPoolProxy.claimableReward(user1), 10000 * rewardRate);
    }
}
