// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, REWARD_MANAGER, FEE_RECEIVER, _1_MILLION
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS, REWARD_MANAGER_GAIN, REWARD_MANAGER_PRECISION} from "./TestConfig.sol";
import {IRewardManager, LockDuration} from "../src/interfaces/core/IRewardManager.sol";

contract RewardManagerTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;
    uint256 maxFeePercentage = 0.05e18; // 5%

    struct RewardManagerVars {
        uint256[5] SATGain;
        // user state
        uint256[5] userCollBefore;
        uint256[5] userCollAfter;
        uint256[5] userDebtBefore;
        uint256[5] userDebtAfter;
        uint256[5] userMintingFee;
        uint256 ClaimableOSHIinSP;
        uint256[5] claimableTroveReward;
    }

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        user5 = vm.addr(5);

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

    function _troveClaimOSHIReward(address caller) internal returns (uint256 amount) {
        vm.prank(caller);
        amount = troveManagerBeaconProxy.claimReward(caller);
    }

    function _spClaimReward(address caller) internal returns (uint256 amount) {
        vm.prank(caller);
        amount = stabilityPoolProxy.claimReward(caller);
    }

    function _stakeOSHIToRewardManagerProxy(address caller, uint256 amount, LockDuration lock) internal {
        vm.startPrank(caller);
        oshiTokenProxy.approve(address(rewardManagerProxy), amount);
        rewardManagerProxy.stake(amount, lock);
        vm.stopPrank();
    }

    function _unstakeOSHIFromRewardManagerProxy(address caller, uint256 amount) internal {
        vm.startPrank(caller);
        rewardManagerProxy.unstake(amount);
        vm.stopPrank();
    }

    function _claimsRewardManagerProxyReward(address caller) internal {
        vm.startPrank(caller);
        rewardManagerProxy.claimReward();
        vm.stopPrank();
    }

    function _redeemCollateral(address caller, uint256 redemptionAmount) internal {
        uint256 price = troveManagerBeaconProxy.fetchPrice();
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount) =
            hintHelpers.getRedemptionHints(troveManagerBeaconProxy, redemptionAmount, price, 0);
        (address hintAddress,,) = hintHelpers.getApproxHint(troveManagerBeaconProxy, partialRedemptionHintNICR, 10, 42);

        (address upperPartialRedemptionHint, address lowerPartialRedemptionHint) =
            sortedTrovesBeaconProxy.findInsertPosition(partialRedemptionHintNICR, hintAddress, hintAddress);

        // redeem
        vm.prank(caller);
        troveManagerBeaconProxy.redeemCollateral(
            truncatedDebtAmount,
            firstRedemptionHint,
            upperPartialRedemptionHint,
            lowerPartialRedemptionHint,
            partialRedemptionHintNICR,
            0,
            maxFeePercentage
        );
    }

    function _recordUserStateBeforeToVar(RewardManagerVars memory vars) internal view {
        (vars.userCollBefore[0], vars.userDebtBefore[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollBefore[1], vars.userDebtBefore[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollBefore[2], vars.userDebtBefore[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollBefore[3], vars.userDebtBefore[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
        (vars.userCollBefore[4], vars.userDebtBefore[4]) = troveManagerBeaconProxy.getTroveCollAndDebt(user5);
        for (uint256 i; i < 5; ++i) {
            if (vars.userDebtBefore[i] < GAS_COMPENSATION) {
                continue;
            } else {
                vars.userMintingFee[i] = (vars.userDebtBefore[i] - GAS_COMPENSATION) * 5 / 1000;
            }
        }
    }

    function _recordUserStateAfterToVar(RewardManagerVars memory vars) internal view {
        (vars.userCollAfter[0], vars.userDebtAfter[0]) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (vars.userCollAfter[1], vars.userDebtAfter[1]) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (vars.userCollAfter[2], vars.userDebtAfter[2]) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        (vars.userCollAfter[3], vars.userDebtAfter[3]) = troveManagerBeaconProxy.getTroveCollAndDebt(user4);
        (vars.userCollAfter[4], vars.userDebtAfter[4]) = troveManagerBeaconProxy.getTroveCollAndDebt(user5);
    }

    function _recordClaimableTroveRewardToVar(RewardManagerVars memory vars) internal view {
        vars.claimableTroveReward[0] = troveManagerBeaconProxy.claimableReward(user1);
        vars.claimableTroveReward[1] = troveManagerBeaconProxy.claimableReward(user2);
        vars.claimableTroveReward[2] = troveManagerBeaconProxy.claimableReward(user3);
        vars.claimableTroveReward[3] = troveManagerBeaconProxy.claimableReward(user4);
        vars.claimableTroveReward[4] = troveManagerBeaconProxy.claimableReward(user5);
    }

    function test_AccrueInterst2TroveCorrect() public {
        // open a trove
        _openTrove(user1, 1e18, 1000e18);
        _openTrove(user2, 1e18, 1000e18);
        (uint256 user1CollBefore, uint256 user1DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollBefore, uint256 user2DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);

        // 365 days later
        vm.warp(block.timestamp + 365 days);

        (uint256 user1CollAfter, uint256 user1DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollAfter, uint256 user2DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        assertEq(user1CollAfter, user1CollBefore);
        assertEq(user2CollAfter, user2CollBefore);

        // check the debt
        uint256 expectedDebt = (user1DebtBefore + user2DebtBefore) * (10000 + INTEREST_RATE_IN_BPS) / 10000;
        uint256 delta = SatoshiMath._getAbsoluteDifference(expectedDebt, user1DebtAfter + user2DebtAfter);
        assert(delta < 1000);
    }

    function test_OneTimeBorrowFeeIncreaseF_SAT() public {
        _openTrove(user1, 1e18, 1000e18);
        // after 5 years
        vm.warp(block.timestamp + 365 days * 5);
        _troveClaimOSHIReward(user1);
        uint256 expectedOSHIAmount = 20 * _1_MILLION;
        assertApproxEqAbs(oshiTokenProxy.balanceOf(user1), expectedOSHIAmount, 1e10);
        assertEq(debtTokenProxy.balanceOf(address(rewardManagerProxy)), 5e18);
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.satForFeeReceiver(), 5e18);
    }

    function test_FeeReceiverReceiveCorrectAmount() public {
        _openTrove(user1, 1e18, 1000e18);
        // after 5 years
        vm.warp(block.timestamp + 365 days * 5);
        _troveClaimOSHIReward(user1);
        uint256 expectedOSHIAmount = 20 * _1_MILLION;
        assertApproxEqAbs(oshiTokenProxy.balanceOf(user1), expectedOSHIAmount, 1e10);
        assertEq(debtTokenProxy.balanceOf(address(rewardManagerProxy)), 5e18);
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.satForFeeReceiver(), 5e18);

        vm.prank(OWNER);
        rewardManagerProxy.claimFee();
        assertEq(debtTokenProxy.balanceOf(FEE_RECEIVER), 5e18);
    }

    function test_unstakeFromRMBeforeUnlock() public {
        // user1 open a trove
        _openTrove(user1, 1e18, 1000e18);
        vm.warp(block.timestamp + 10 days);
        // user1 claim OSHI reward
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount, LockDuration.THREE);
        vm.warp(block.timestamp + 10 days);
        // no oshi to unstake
        vm.startPrank(user1);
        vm.expectRevert("RewardManager: No OSHI to withdraw");
        rewardManagerProxy.unstake(OSHIAmount);
    }

    function test_unstakeFromRMAfterUnlock() public {
        // user1 open a trove
        _openTrove(user1, 1e18, 1000e18);
        vm.warp(block.timestamp + 10 days);
        // user1 claim OSHI reward
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount, LockDuration.THREE);

        // 3 months later, user1 can unstake OSHI
        vm.warp(block.timestamp + 90 days);
        uint256 unlockedAmount = rewardManagerProxy.getAvailableUnstakeAmount(user1);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount);
        assertEq(rewardManagerProxy.totalOSHIWeightedStaked(), 0);
        assertEq(oshiTokenProxy.balanceOf(user1), OSHIAmount);
        assertEq(OSHIAmount, unlockedAmount);
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.getPendingCollGain(user1)[0], 0);
    }

    function test_stakeAndUnstakePartial() public {
        // user1 open a trove
        _openTrove(user1, 1e18, 1000e18);
        vm.warp(block.timestamp + 10 days);
        // user1 claim OSHI reward
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount / 2, LockDuration.THREE);
        vm.warp(block.timestamp + 1 days);
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount / 2, LockDuration.THREE);

        // 3 months later, user1 can unstake OSHI
        vm.warp(block.timestamp + 89 days);
        uint256 unlockedAmount = rewardManagerProxy.getAvailableUnstakeAmount(user1);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount / 2 - 1);
        vm.warp(block.timestamp + 1 days);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount / 2 + 1);
        assertEq(rewardManagerProxy.totalOSHIWeightedStaked(), 0);
        assertEq(oshiTokenProxy.balanceOf(user1), OSHIAmount);
        assertEq(OSHIAmount / 2, unlockedAmount);
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.getPendingCollGain(user1)[0], 0);
    }

    function test_unstake12MonthFromRMAfterUnlock() public {
        // user1 open a trove
        _openTrove(user1, 1e18, 1000e18);
        vm.warp(block.timestamp + 10 days);
        // user1 claim OSHI reward
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount / 2, LockDuration.THREE);
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount / 2, LockDuration.TWELVE);

        // 3 months later, user1 can unstake OSHIAmount/2 OSHI
        vm.warp(block.timestamp + 90 days);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount);
        assertEq(oshiTokenProxy.balanceOf(user1), OSHIAmount / 2);

        // 12 months later, user1 can unstake another OSHIAmount/2 OSHI
        vm.warp(block.timestamp + 360 days);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount);
        assertEq(rewardManagerProxy.totalOSHIWeightedStaked(), 0);
        assertEq(oshiTokenProxy.balanceOf(user1), OSHIAmount);
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.getPendingCollGain(user1)[0], 0);
    }

    function test_StakeOSHIToRM() public {
        RewardManagerVars memory vars;
        // user1 open a trove
        _openTrove(user1, 1e18, 1000e18);
        _recordUserStateBeforeToVar(vars);
        vm.warp(block.timestamp + 10 days);
        // user1 claim OSHI reward
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount, LockDuration.THREE);
        assertEq(OSHIAmount, rewardManagerProxy.totalOSHIWeightedStaked());
        vm.warp(block.timestamp + 355 days);
        _updateRoundData(
            RoundData({
                answer: 60000_00_000_000, // 60000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user2, 1e18, 1000e18);

        // user1 claim sOSHI reward (protocol revenue)
        // uint256 interest = (vars.userDebtBefore[0]) * INTEREST_RATE_IN_BPS / 10000;
        uint256 expectedReward = (50567282792268718326 + 5e18) * REWARD_MANAGER_GAIN / REWARD_MANAGER_PRECISION;
        uint256 user1PendingSATGain = rewardManagerProxy.getPendingSATGain(user1);
        assertApproxEqAbs(expectedReward, user1PendingSATGain, 1e10);
        _claimsRewardManagerProxyReward(user1);

        // check pending reward is 0
        assertEq(rewardManagerProxy.getPendingSATGain(user1), 0);
        assertEq(rewardManagerProxy.getPendingCollGain(user1)[0], 0);
        // check the state
        // user2 minting fee + user1 intererst
        assertEq(user1PendingSATGain, debtTokenProxy.balanceOf(user1) - 1000e18);
        _unstakeOSHIFromRewardManagerProxy(user1, OSHIAmount);
        assertEq(rewardManagerProxy.totalOSHIWeightedStaked(), 0);
    }

    function test_getOSHIFromSP() public {
        RewardManagerVars memory vars;
        _openTrove(user1, 1e18, 1000e18);
        _provideToSP(user1, 1000e18);
        // after 5 years
        vm.warp(block.timestamp + 365 days);
        uint256 expectedOSHIAmount = 2 * _1_MILLION;
        vars.ClaimableOSHIinSP = stabilityPoolProxy.claimableReward(user1);
        assertApproxEqAbs(vars.ClaimableOSHIinSP, expectedOSHIAmount, 1e10);
        _spClaimReward(user1);
        assertEq(oshiTokenProxy.balanceOf(user1), vars.ClaimableOSHIinSP);
        assertEq(stabilityPoolProxy.claimableReward(user1), 0);
    }

    // // getPendingCollGain returns the correct amount
    function test_getPendingCollGain() public {
        RewardManagerVars memory vars;
        _openTrove(user1, 1e18, 1000e18);
        _openTrove(user2, 1e18, 1000e18);
        _openTrove(user3, 1e18, 1000e18);
        _openTrove(user4, 1e18, 1000e18);
        _openTrove(user5, 1e18, 1000e18);

        vm.warp(block.timestamp + 365 days);
        _recordClaimableTroveRewardToVar(vars);
        _recordUserStateBeforeToVar(vars);
        // check user OSHI reward
        assertEq(vars.claimableTroveReward[0], vars.claimableTroveReward[1]);
        uint256 expectedReward = troveManagerBeaconProxy.rewardRate() * 365 days / 5;
        assertApproxEqAbs(vars.claimableTroveReward[0], expectedReward, 1000);
        assertEq(vars.claimableTroveReward[0], vars.claimableTroveReward[1]);
        assertEq(vars.claimableTroveReward[0], vars.claimableTroveReward[2]);
        assertEq(vars.claimableTroveReward[0], vars.claimableTroveReward[3]);
        assertEq(vars.claimableTroveReward[0], vars.claimableTroveReward[4]);

        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        assertEq(OSHIAmount, vars.claimableTroveReward[0]);

        // user1 stake OSHI to reward manager
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount, LockDuration.TWELVE);

        _updateRoundData(
            RoundData({
                answer: 60000_00_000_000, // 60000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );

        // user2 redeem -> reward manager will get coll gain and interest
        uint256 redeemAmount = 100e18;
        _redeemCollateral(user2, redeemAmount);

        uint256 redemptionRate = troveManagerBeaconProxy.getRedemptionRate();
        assertGt(vars.userDebtBefore[1], debtTokenProxy.balanceOf(user2));

        uint256 price = troveManagerBeaconProxy.fetchPrice();
        uint256 expectedRedemptionAmount = redeemAmount * 1e18 / price;
        uint256 expectedToRM = expectedRedemptionAmount * redemptionRate / 1e18;

        assertEq(collateralMock.balanceOf(address(rewardManagerProxy)), expectedToRM);

        // check pending coll gain
        uint256 pendingCollGain = rewardManagerProxy.getPendingCollGain(user1)[0];
        assertApproxEqAbs(pendingCollGain, expectedToRM * REWARD_MANAGER_GAIN / REWARD_MANAGER_PRECISION, 100);

        uint256 pendingCollForFeeReceiver = rewardManagerProxy.collForFeeReceiver(0);
        assertApproxEqAbs(
            pendingCollForFeeReceiver, expectedToRM - expectedToRM * REWARD_MANAGER_GAIN / REWARD_MANAGER_PRECISION, 100
        );
    }

    // test owner can increase coll to reward manager
    function test_increaseSATPerUintStakedbyOwner() public {
        _openTrove(user1, 1e18, 1000e18);
        _openTrove(user2, 1e18, 1000e18);
        _openTrove(user3, 1e18, 1000e18);
        _openTrove(user4, 1e18, 1000e18);
        _openTrove(user5, 1e18, 1000e18);

        // check fee receiver SAT gain in reward manager, no one stake in reward manager
        assertEq(rewardManagerProxy.satForFeeReceiver(), 5e18 * 5);

        vm.prank(OWNER);
        rewardManagerProxy.claimFee();
        assertEq(debtTokenProxy.balanceOf(FEE_RECEIVER), 5e18 * 5);

        // someone stake OSHI in Reward Manager
        vm.warp(block.timestamp + 30 days);
        uint256 OSHIAmount = _troveClaimOSHIReward(user1);
        _stakeOSHIToRewardManagerProxy(user1, OSHIAmount, LockDuration.THREE);

        vm.startPrank(FEE_RECEIVER);
        debtTokenProxy.approve(address(rewardManagerProxy), 5e18 * 5);
        rewardManagerProxy.increaseSATPerUintStaked(5e18 * 5);
        vm.stopPrank();
        assert(rewardManagerProxy.F_SAT() > 0);
    }
}
