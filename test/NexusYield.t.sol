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
import {INexusYieldManager} from "../src/interfaces/core/INexusYieldManager.sol";

contract NexusYieldTest is Test, DeployBase, TroveBase, TestConfig, Events {
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
        nexusYieldProxy.setAssetConfig(address(collateralMock), 10, 10, 10000e18, 1000e18, address(0), false, 3 days);
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
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 1e18);

        // check user1 sat balance
        assertEq(debtTokenProxy.balanceOf(user1), 1e18);

        // swap out
        nexusYieldProxy.swapOutPrivileged(address(collateralMock), user1, 1e18);
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
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        (uint256 assetOut, uint256 feeOut) = nexusYieldProxy.previewSwapOut(address(collateralMock), amount);
        assertEq(fee, feeOut);
        assertEq(assetOut + feeOut, amount);
        vm.stopPrank();
    }

    function test_previewSwapStableForSAT() public {
        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeIn(address(collateralMock)) / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        (uint256 previewAmount,) = nexusYieldProxy.previewSwapIn(address(collateralMock), amount);
        assertEq(previewAmount, amount - fee);
    }

    function test_scheduleSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        debtTokenProxy.approve(address(nexusYieldProxy), amount);
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);
        // try to withdraw => should fail
        vm.expectRevert(INexusYieldManager.WithdrawalNotAvailable.selector);
        nexusYieldProxy.withdraw(address(collateralMock));

        vm.warp(block.timestamp + nexusYieldProxy.swapWaitingPeriod(address(collateralMock)));
        nexusYieldProxy.withdraw(address(collateralMock));
        assertEq(collateralMock.balanceOf(user1), amount - fee);
        vm.stopPrank();
    }

    function test_scheduleTwice() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);

        uint256 amount = 1e18;
        uint256 fee = amount * nexusYieldProxy.feeOut(address(collateralMock)) / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        debtTokenProxy.approve(address(nexusYieldProxy), amount + fee);
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);

        vm.expectRevert(INexusYieldManager.WithdrawalAlreadyScheduled.selector);
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);
    }

    function test_mintCapReached() public {
        deal(address(collateralMock), user1, 1000000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1000000e18);
        vm.expectRevert(INexusYieldManager.DebtTokenMintCapReached.selector);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1000000e18);
        vm.stopPrank();
    }
}
