// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    GAS_COMPENSATION,
    TestConfig,
    REWARD_MANAGER,
    FEE_RECEIVER,
    _1_MILLION,
    INTEREST_RATE_IN_BPS
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS, REWARD_MANAGER_GAIN, REWARD_MANAGER_PRECISION} from "./TestConfig.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";

contract TroveManagerTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;

    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

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

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function test_getTotalActiveCollateral() public {
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 0);
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 1e18);
    }

    function test_hasPendingRewards() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.hasPendingRewards(OWNER), false);
        assertEq(troveManagerBeaconProxy.hasPendingRewards(DEPLOYER), false);
    }

    function test_getRedemptionRate() public {
        assertEq(troveManagerBeaconProxy.getRedemptionRate(), 0.005e18);
    }

    function test_getRedemptionRateWithDecay() public {
        assertEq(troveManagerBeaconProxy.getRedemptionRateWithDecay(), 0.005e18);
    }

    function test_getBorrowingRate() public {
        assertEq(troveManagerBeaconProxy.getBorrowingRate(), 0.005e18);
    }

    function test_getBorrowingFee() public {
        assertEq(troveManagerBeaconProxy.getBorrowingFee(1000e18), 1000e18 / 200);
    }

    function test_setClaimStartTime() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.setClaimStartTime(100);
        assertEq(troveManagerBeaconProxy.claimStartTime(), 100);
    }

    function test_getTotalActiveDebt() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTotalActiveDebt(), 1000e18 + 1000e18 / 200 + GAS_COMPENSATION);
    }

    function test_getRedemptionFeeWithDecay() public {
        assertEq(troveManagerBeaconProxy.getRedemptionFeeWithDecay(1000e18), 1000e18 / 200);
    }

    function test_getTroveStake() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTroveStake(OWNER), 1e18);
    }

    function test_getEntireSystemDebt() public {
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getEntireSystemDebt(), 1000e18 + 1000e18 / 200 + GAS_COMPENSATION);

        vm.warp(block.timestamp + 365 days);
        assertApproxEqAbs(
            troveManagerBeaconProxy.getEntireSystemDebt(),
            (1000e18 + 1000e18 / 200 + GAS_COMPENSATION) * (10000 + INTEREST_RATE_IN_BPS) / 10000,
            10
        );
    }

    function test_setPause() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.setPaused(true);
        assertEq(troveManagerBeaconProxy.paused(), true);
    }

    function test_startSunset() public {
        vm.prank(OWNER);
        troveManagerBeaconProxy.startSunset();
        assertEq(troveManagerBeaconProxy.sunsetting(), true);
        assertEq(troveManagerBeaconProxy.lastActiveIndexUpdate(), block.timestamp);
        assertEq(troveManagerBeaconProxy.redemptionFeeFloor(), 0);
        assertEq(troveManagerBeaconProxy.maxSystemDebt(), 0);
    }

    function test_collectInterests() public {
        _openTrove(OWNER, 1e18, 1000e18);
        vm.expectRevert("Nothing to collect");
        troveManagerBeaconProxy.collectInterests();

        vm.warp(block.timestamp + 365 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );
        _openTrove(DEPLOYER, 1e18, 1000e18);
        vm.expectRevert("Nothing to collect");
        troveManagerBeaconProxy.collectInterests();
        assertGt(debtTokenProxy.balanceOf(address(rewardManagerProxy)), 0);
    }
}
