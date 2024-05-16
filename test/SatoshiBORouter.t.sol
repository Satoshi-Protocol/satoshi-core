// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {ISatoshiBORouter} from "../src/helpers/interfaces/ISatoshiBORouter.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";

contract SatoshiBORouterTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    ISatoshiBORouter satoshiBORouter;
    address user;

    function setUp() public override {
        super.setUp();

        // testing user
        user = vm.addr(1);

        // use WETH as collateral
        weth = IWETH(_deployWETH(DEPLOYER));
        deal(address(weth), 10000e18);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, weth, deploymentParams
        );

        // deploy helper contracts
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        satoshiBORouter = ISatoshiBORouter(_deploySatoshiBORouter(DEPLOYER));

        // user set delegate approval for satoshiBORouter
        vm.startPrank(user);
        borrowerOperationsProxy.setDelegateApproval(address(satoshiBORouter), true);
        vm.stopPrank();
    }

    function testOpenTroveByRouter() public {
        LocalVars memory vars;
        // open trove params
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD

        vm.startPrank(user);
        deal(user, 1e18);

        // state before
        vars.rewardManagerDebtAmtBefore = debtTokenProxy.balanceOf(satoshiCore.rewardManager());
        vars.gasPoolDebtAmtBefore = debtTokenProxy.balanceOf(address(gasPool));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));

        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);

        /* check events emitted correctly in tx */
        // check BorrowingFeePaid event
        vm.expectEmit(true, true, true, true, address(borrowerOperationsProxy));
        emit BorrowingFeePaid(user, weth, vars.borrowingFee);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check NewDeployment event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.open);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, vars.collAmt, vars.debtAmt, GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.openTrove{value: vars.collAmt}(
            troveManagerBeaconProxy,
            0.05e18, /* vars.maxFeePercentage 5% */
            vars.collAmt,
            vars.debtAmt,
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.rewardManagerDebtAmtAfter = debtTokenProxy.balanceOf(satoshiCore.rewardManager());
        vars.gasPoolDebtAmtAfter = debtTokenProxy.balanceOf(address(gasPool));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.rewardManagerDebtAmtAfter, vars.rewardManagerDebtAmtBefore + vars.borrowingFee);
        assertEq(vars.gasPoolDebtAmtAfter, vars.gasPoolDebtAmtBefore + GAS_COMPENSATION);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.debtAmt);
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.collAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.collAmt);

        vm.stopPrank();
    }

    function testAddCollByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;

        vm.startPrank(user);
        deal(user, vars.addCollAmt);
        weth.approve(address(borrowerOperationsProxy), vars.addCollAmt);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.debtAmt,
            GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.addColl{value: vars.addCollAmt}(
            troveManagerBeaconProxy, vars.addCollAmt, vars.upperHint, vars.lowerHint
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);

        vm.stopPrank();
    }

    function testwithdrawCollByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;

        vm.startPrank(user);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.debtAmt,
            GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.withdrawColl(
            troveManagerBeaconProxy, vars.withdrawCollAmt, vars.upperHint, vars.lowerHint, new bytes[](0)
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);

        vm.stopPrank();
    }

    function testWithdrawDebtByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawDebtAmt = 10000e18;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);

        // state before
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.collAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.withdrawDebt(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            vars.withdrawDebtAmt,
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testRepayDebtByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.repayDebtAmt = 5000e18;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        debtTokenProxy.approve(address(satoshiBORouter), vars.repayDebtAmt);

        // state before
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.collAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );

        // tx execution
        satoshiBORouter.repayDebt(troveManagerBeaconProxy, vars.repayDebtAmt, vars.upperHint, vars.lowerHint);

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_AddCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        deal(user, vars.addCollAmt);
        debtTokenProxy.approve(address(satoshiBORouter), vars.repayDebtAmt);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );

        // tx execution
        satoshiBORouter.adjustTrove{value: vars.addCollAmt}(
            troveManagerBeaconProxy,
            0, /* vars.maxFeePercentage */
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_AddCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e18;
        vars.withdrawDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);
        deal(user, vars.addCollAmt);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );

        // tx execution
        satoshiBORouter.adjustTrove{value: vars.addCollAmt}(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_WithdrawCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user);
        debtTokenProxy.approve(address(satoshiBORouter), vars.repayDebtAmt);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );

        // tx execution
        satoshiBORouter.adjustTrove(
            troveManagerBeaconProxy,
            0, /* vars.maxFeePercentage */
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveByRouter_WithdrawCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e18;
        vars.withdrawDebtAmt = 2000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user);

        // state before
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            vars.totalCollAmt,
            vars.totalNetDebtAmt,
            GAS_COMPENSATION
        );

        // tx execution
        satoshiBORouter.adjustTrove(
            troveManagerBeaconProxy,
            vars.maxFeePercentage,
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            new bytes[](0)
        );

        // state after
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testCloseTroveByRouter() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user,
            user,
            weth,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vm.startPrank(user);
        //  mock user debt token balance
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.repayDebtAmt = vars.debtAmt + vars.borrowingFee;
        deal(address(debtTokenProxy), user, vars.repayDebtAmt);
        debtTokenProxy.approve(address(satoshiBORouter), vars.repayDebtAmt);

        // state before
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();
        vars.userBalanceBefore = user.balance;
        vars.troveManagerCollateralAmtBefore = weth.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user, 0, 0, 0, TroveManagerOperation.close);

        // tx execution
        satoshiBORouter.closeTrove(troveManagerBeaconProxy);

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();
        vars.userBalanceAfter = user.balance;
        vars.troveManagerCollateralAmtAfter = weth.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userDebtAmtAfter, 0);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt - GAS_COMPENSATION);
        assertEq(vars.userBalanceAfter, vars.userBalanceBefore + vars.collAmt);
        // assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.collAmt);

        vm.stopPrank();
    }
}
