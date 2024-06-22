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
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, REWARD_MANAGER, FEE_RECEIVER} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS} from "./TestConfig.sol";
import {INexusYield} from "../src/interfaces/core/INexusYield.sol";

contract PegStabiltityTest is Test, DeployBase, TroveBase, TestConfig, Events {
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

        // deploy peg stability module contract
        _deployNexusYieldProxy(DEPLOYER);

        vm.startPrank(OWNER);
        debtTokenProxy.rely(address(nexusYieldProxy));
        rewardManagerProxy.setWhitelistCaller(address(nexusYieldProxy), true);
        vm.stopPrank();
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

    function _closeTrove(address caller) internal {
        TroveBase.closeTrove(borrowerOperationsProxy, troveManagerBeaconProxy, caller);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _transfer(address caller, address token, address to, uint256 amount) internal {
        vm.startPrank(caller);
        IERC20(token).transfer(to, amount);
        vm.stopPrank();
    }

    function test_swapInAndOut_noFee() public {
        // assume collateral is the stable coin
        deal(address(collateralMock), user1, 100e18);

        vm.prank(OWNER);
        nexusYieldProxy.setPrivileged(user1, true);

        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1e18);
        nexusYieldProxy.swapStableForSATPrivileged(user1, 1e18);

        // check user1 sat balance
        assertEq(debtTokenProxy.balanceOf(user1), 1e18);

        // swap out
        nexusYieldProxy.swapSATForStablePrivileged(user1, 1e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);

        vm.stopPrank();
    }

    function test_pause() public {
        vm.prank(OWNER);
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isPaused());
    }

    function test_resume() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isPaused());
        nexusYieldProxy.resume();
        assertFalse(nexusYieldProxy.isPaused());
        vm.stopPrank();
    }

    function test_setFeeIn() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.setFeeIn(100);
        assertEq(nexusYieldProxy.feeIn(), 100);
        vm.stopPrank();
    }

    function test_setFeeOut() public {
        vm.prank(OWNER);
        nexusYieldProxy.setFeeOut(100);
        assertEq(nexusYieldProxy.feeOut(), 100);
    }

    function test_setSATMintCap() public {
        vm.prank(OWNER);
        nexusYieldProxy.setSATMintCap(100e18);
        assertEq(nexusYieldProxy.satMintCap(), 100e18);
    }

    function test_setRewardManager() public {
        vm.prank(OWNER);
        nexusYieldProxy.setRewardManager(REWARD_MANAGER);
        assertEq(nexusYieldProxy.rewardManagerAddr(), REWARD_MANAGER);
    }

    function test_setUsingOracle() public {
        vm.prank(OWNER);
        nexusYieldProxy.setUsingOracle(true);
        assertTrue(nexusYieldProxy.usingOracle());
    }

    function test_setOracle() public {
        vm.prank(OWNER);
        nexusYieldProxy.setOracle(oracleMockAddr);
        assertEq(address(nexusYieldProxy.oracle()), oracleMockAddr);
    }

    function test_setSwapWaitingPeriod() public {
        vm.prank(OWNER);
        nexusYieldProxy.setSwapWaitingPeriod(2 days);
        assertEq(nexusYieldProxy.swapWaitingPeriod(), 2 days);
    }

    function test_transerTokenToPrivilegedVault() public {
        vm.startPrank(OWNER);
        deal(address(collateralMock), address(nexusYieldProxy), 100e18);
        nexusYieldProxy.setPrivileged(user1, true);
        nexusYieldProxy.transerTokenToPrivilegedVault(address(collateralMock), user1, 100e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);
        vm.stopPrank();
    }

    function test_previewSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapStableForSAT(user1, 100e18);
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut() / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        assertEq(nexusYieldProxy.previewSwapSATForStable(amount), amount + fee);

        vm.stopPrank();
    }

    function test_previewSwapStableForSAT() public {
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeIn() / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        assertEq(nexusYieldProxy.previewSwapStableForSAT(amount), amount - fee);
    }

    function test_scheduleSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapStableForSAT(user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut() / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        debtTokenProxy.approve(address(nexusYieldProxy), amount + fee);
        nexusYieldProxy.scheduleSwapSATForStable(amount);
        // try to withdraw => should fail
        vm.expectRevert(INexusYield.WithdrawalNotAvailable.selector);
        nexusYieldProxy.withdrawStable();

        vm.warp(block.timestamp + nexusYieldProxy.swapWaitingPeriod());
        nexusYieldProxy.withdrawStable();
        assertEq(collateralMock.balanceOf(user1), amount);
        vm.stopPrank();
    }

    function test_scheduleTwice() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapStableForSAT(user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut() / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        debtTokenProxy.approve(address(nexusYieldProxy), amount + fee);
        nexusYieldProxy.scheduleSwapSATForStable(amount);

        vm.expectRevert(INexusYield.WithdrawalAlreadyScheduled.selector);
        nexusYieldProxy.scheduleSwapSATForStable(amount);
    }

    function test_mintCapReached() public {
        deal(address(collateralMock), user1, 10000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 10000e18);
        vm.expectRevert(INexusYield.SATMintCapReached.selector);
        nexusYieldProxy.swapStableForSAT(user1, 10000e18);
        vm.stopPrank();
    }
}
