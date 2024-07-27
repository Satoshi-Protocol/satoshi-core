// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

contract mock6 is ERC20 {
    constructor() ERC20("MOCK", "MOCK") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract mock27 is ERC20 {
    constructor() ERC20("MOCK", "MOCK") {}

    function decimals() public pure override returns (uint8) {
        return 27;
    }
}

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
        nexusYieldProxy.setAssetConfig(
            address(collateralMock), 10, 10, 10000e18, 1000e18, address(0), false, 3 days, 1.1e18, 0.9e18
        );
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

        // check the debtTokenMinted
        assertEq(nexusYieldProxy.debtTokenMinted(address(collateralMock)), 1e18);

        // check user1 sat balance
        assertEq(debtTokenProxy.balanceOf(user1), 1e18);

        // swap out
        nexusYieldProxy.swapOutPrivileged(address(collateralMock), user1, 1e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);

        vm.stopPrank();
    }

    function test_pause() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isPaused());
        // pause again
        vm.expectRevert(INexusYieldManager.AlreadyPaused.selector);
        nexusYieldProxy.pause();
        vm.stopPrank();
    }

    function test_resume() public {
        vm.startPrank(OWNER);
        // not pause should revert
        vm.expectRevert(INexusYieldManager.NotPaused.selector);
        nexusYieldProxy.resume();
        nexusYieldProxy.pause();
        assertTrue(nexusYieldProxy.isPaused());
        nexusYieldProxy.resume();
        assertFalse(nexusYieldProxy.isPaused());
        vm.stopPrank();
    }

    function test_transerTokenToPrivilegedVault() public {
        vm.startPrank(OWNER);
        deal(address(collateralMock), address(nexusYieldProxy), 100e18);
        // transfer to non-privileged address should revert
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.NotPrivileged.selector, user1));
        nexusYieldProxy.transerTokenToPrivilegedVault(address(collateralMock), user1, 100e18);
        nexusYieldProxy.setPrivileged(user1, true);
        nexusYieldProxy.transerTokenToPrivilegedVault(address(collateralMock), user1, 100e18);
        assertEq(collateralMock.balanceOf(user1), 100e18);
        vm.stopPrank();
    }

    function test_swapIn() public {
        deal(address(collateralMock), user1, 10001e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1001e18);
        uint256 dailyMintCount = nexusYieldProxy.dailyMintCount(address(collateralMock));
        uint256 amounToMint = 1001e18;
        uint256 dailyDebtTokenMintCap = nexusYieldProxy.dailyDebtTokenMintCap(address(collateralMock));
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManager.DebtTokenDailyMintCapReached.selector,
                dailyMintCount,
                amounToMint,
                dailyDebtTokenMintCap
            )
        );
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1001e18);

        nexusYieldProxy.swapIn(address(collateralMock), user1, 1e18);

        // the next day
        vm.warp(block.timestamp + 1 days);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 2e18);
        assertEq(nexusYieldProxy.dailyMintCount(address(collateralMock)), 2e18);

        // swapIn 0
        vm.expectRevert(INexusYieldManager.ZeroAmount.selector);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 0);

        vm.stopPrank();
    }

    function test_swapInZeroFee() public {
        vm.prank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateralMock), 0, 0, 10000e18, 1000e18, address(0), false, 3 days, 1.1e18, 0.9e18
        );

        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1e18);
        assertEq(debtTokenProxy.balanceOf(user1), 1e18);
        vm.stopPrank();
    }

    function test_previewSwapSATForStable() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
        // check daily mint cap remain
        assertEq(nexusYieldProxy.debtTokenDailyMintCapRemain(address(collateralMock)), 900e18);
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

        (uint256 previewAmount, uint256 previewFee) = nexusYieldProxy.previewSwapOut(address(collateralMock), amount);
        (uint256 pendingAmount, uint32 withdrawalTime) =
            nexusYieldProxy.pendingWithdrawal(address(collateralMock), user1);
        address[] memory assets = new address[](1);
        assets[0] = address(collateralMock);
        (uint256[] memory pendingAmounts, uint32[] memory withdrawalTimes) =
            nexusYieldProxy.pendingWithdrawals(assets, user1);

        assertEq(pendingAmounts[0], pendingAmount);
        assertEq(withdrawalTimes[0], withdrawalTime);
        assertEq(previewFee, fee);
        assertEq(previewAmount, amount - fee);
        assertEq(pendingAmount, previewAmount);
        assertEq(withdrawalTime, block.timestamp + nexusYieldProxy.swapWaitingPeriod(address(collateralMock)));

        // try to withdraw => should fail
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.WithdrawalNotAvailable.selector, withdrawalTime));
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

        (, uint32 withdrawalTime) = nexusYieldProxy.pendingWithdrawal(address(collateralMock), user1);

        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.WithdrawalAlreadyScheduled.selector, withdrawalTime));
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);
    }

    function test_swapOutBalanceNotEnough() public {
        vm.prank(OWNER);
        nexusYieldProxy.setPrivileged(user2, true);
        deal(address(collateralMock), user1, 100e18);
        deal(address(collateralMock), user2, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
        vm.stopPrank();

        vm.startPrank(user2);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        nexusYieldProxy.swapIn(address(collateralMock), user2, 100e18);

        uint256 amount = 101e18;
        debtTokenProxy.approve(address(nexusYieldProxy), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManager.NotEnoughDebtToken.selector, debtTokenProxy.balanceOf(user2), amount
            )
        );
        nexusYieldProxy.scheduleSwapOut(address(collateralMock), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManager.NotEnoughDebtToken.selector, debtTokenProxy.balanceOf(user2), amount
            )
        );
        nexusYieldProxy.swapOutPrivileged(address(collateralMock), user2, amount);

        vm.stopPrank();
    }

    function test_mintCapReached() public {
        vm.prank(OWNER);
        nexusYieldProxy.setPrivileged(user1, true);
        deal(address(collateralMock), user1, 1000000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 1000000e18);
        uint256 debtTokenMinted = nexusYieldProxy.debtTokenMinted(address(collateralMock));
        uint256 amountToMint = 1000000e18;
        uint256 debtTokenMintCap = nexusYieldProxy.debtTokenMintCap(address(collateralMock));
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManager.DebtTokenMintCapReached.selector, debtTokenMinted, amountToMint, debtTokenMintCap
            )
        );
        nexusYieldProxy.swapIn(address(collateralMock), user1, 1000000e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                INexusYieldManager.DebtTokenMintCapReached.selector, debtTokenMinted, amountToMint, debtTokenMintCap
            )
        );
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 1000000e18);
        vm.stopPrank();
    }

    function test_sunsetAsset() public {
        vm.startPrank(OWNER);
        nexusYieldProxy.sunsetAsset(address(collateralMock));
        assertFalse(nexusYieldProxy.isAssetSupported(address(collateralMock)));
        vm.stopPrank();
    }

    function test_convertDebtTokenToAssetAmount() public {
        ERC20 coll1 = new mock6();
        ERC20 coll2 = new mock27();

        uint256 amount = nexusYieldProxy.convertDebtTokenToAssetAmount(address(coll1), 1e18);
        assertEq(amount, 1e6);

        amount = nexusYieldProxy.convertDebtTokenToAssetAmount(address(coll2), 1e18);
        assertEq(amount, 1e27);
    }

    function test_convertAssetToDebtTokenAmount() public {
        ERC20 coll1 = new mock6();
        ERC20 coll2 = new mock27();

        uint256 amount = nexusYieldProxy.convertAssetToDebtTokenAmount(address(coll1), 1e6);
        assertEq(amount, 1e18);

        amount = nexusYieldProxy.convertAssetToDebtTokenAmount(address(coll2), 1e27);
        assertEq(amount, 1e18);
    }

    function test_setAssetConfig() public {
        vm.startPrank(OWNER);
        uint256 feeIn = 100000;
        uint256 feeOut = 10;
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.InvalidFee.selector, feeIn, feeOut));
        nexusYieldProxy.setAssetConfig(
            address(collateralMock), feeIn, feeOut, 10000e18, 1000e18, address(0), false, 3 days, 1.1e18, 0.9e18
        );
        nexusYieldProxy.setAssetConfig(
            address(collateralMock), 10, 10, 10000e18, 1000e18, address(0), false, 3 days, 1.1e18, 0.9e18
        );
        assertEq(nexusYieldProxy.feeIn(address(collateralMock)), 10);
        assertEq(nexusYieldProxy.feeOut(address(collateralMock)), 10);
        assertEq(nexusYieldProxy.debtTokenMintCap(address(collateralMock)), 10000e18);
        assertEq(nexusYieldProxy.dailyDebtTokenMintCap(address(collateralMock)), 1000e18);
        assertEq(address(nexusYieldProxy.oracle(address(collateralMock))), address(0));
        assertFalse(nexusYieldProxy.isUsingOracle(address(collateralMock)));
        assertEq(nexusYieldProxy.swapWaitingPeriod(address(collateralMock)), 3 days);
        vm.stopPrank();
    }

    function test_setRewardManager() public {
        vm.prank(OWNER);
        nexusYieldProxy.setRewardManager(user1);
        assertEq(nexusYieldProxy.rewardManagerAddr(), user1);
    }

    function test_isNotActive() public {
        vm.prank(OWNER);
        nexusYieldProxy.pause();

        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        vm.expectRevert(INexusYieldManager.Paused.selector);
        nexusYieldProxy.swapIn(address(collateralMock), user1, 100e18);
    }

    function test_isNotPriviledge() public {
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        vm.expectRevert("NexusYieldManager: caller is not privileged");
        nexusYieldProxy.swapInPrivileged(address(collateralMock), user1, 100e18);
    }

    function test_assetNotSupport() public {
        ERC20 coll = new mock6();
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.AssetNotSupported.selector, address(coll)));
        nexusYieldProxy.swapIn(address(coll), user1, 1e18);
    }

    function test_zeroAddress() public {
        vm.expectRevert(INexusYieldManager.ZeroAddress.selector);
        nexusYieldProxy.swapIn(address(collateralMock), address(0), 100e18);
    }

    function test_amountTooSmall() public {
        deal(address(collateralMock), user1, 100e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), 100e18);
        uint256 amount = 1;
        uint256 feeAmount = amount * nexusYieldProxy.feeIn(address(collateralMock));
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.AmountTooSmall.selector, feeAmount));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
    }

    function test_oraclePriceLessThan1() public {
        _updateRoundData(
            RoundData({answer: 0.9e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), 0.9e18);

        vm.prank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateralMock),
            10,
            10,
            10000e18,
            1000e18,
            address(priceFeedAggregatorProxy),
            true,
            3 days,
            1.1e18,
            0.9e18
        );

        uint256 amount = 100e18;
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
        (, uint256 previewFee) = nexusYieldProxy.previewSwapIn(address(collateralMock), amount);
        uint256 fee =
            amount * 9 / 10 * nexusYieldProxy.feeIn(address(collateralMock)) / nexusYieldProxy.BASIS_POINTS_DIVISOR();
        assertEq(previewFee, fee);
        assertEq(debtTokenProxy.balanceOf(user1), 90e18 - fee);
    }

    function test_priceOutOfRange() public {
        _updateRoundData(
            RoundData({answer: 0.8e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), 0.8e18);

        vm.prank(OWNER);
        nexusYieldProxy.setAssetConfig(
            address(collateralMock),
            10,
            10,
            10000e18,
            1000e18,
            address(priceFeedAggregatorProxy),
            true,
            3 days,
            1.1e18,
            0.9e18
        );

        uint256 amount = 100e18;
        deal(address(collateralMock), user1, 1000e18);
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.InvalidPrice.selector, 0.8e18));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);

        // price > 1.1
        _updateRoundData(
            RoundData({answer: 1.2e8, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );
        assertEq(priceFeedAggregatorProxy.fetchPrice(collateralMock), 1.2e18);

        amount = 100e18;
        vm.startPrank(user1);
        collateralMock.approve(address(nexusYieldProxy), amount);
        vm.expectRevert(abi.encodeWithSelector(INexusYieldManager.InvalidPrice.selector, 1.2e18));
        nexusYieldProxy.swapIn(address(collateralMock), user1, amount);
    }
}
