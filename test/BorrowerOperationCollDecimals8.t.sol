// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {Coll} from "../src/mocks/Coll.sol";

contract BorrowerOperationCollDecimals8 is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    ERC20 collateral;
    address user1;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);

        // deploy collateral token with decimals 8
        collateral = new Coll();
        assertEq(collateral.decimals(), 8);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateral, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
    }

    function testOpenTrove() public {
        LocalVars memory vars;
        // open trove params
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%

        vm.startPrank(user1);
        deal(address(collateral), user1, 1e8);
        collateral.approve(address(borrowerOperationsProxy), 1e8);

        // state before
        vars.rewardManagerDebtAmtBefore = debtTokenProxy.balanceOf(satoshiCore.rewardManager());
        vars.gasPoolDebtAmtBefore = debtTokenProxy.balanceOf(address(gasPool));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);

        /* check events emitted correctly in tx */
        // check BorrowingFeePaid event
        vm.expectEmit(true, true, true, true, address(borrowerOperationsProxy));
        emit BorrowingFeePaid(user1, collateral, vars.borrowingFee);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check NewDeployment event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.open);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, vars.collAmt, vars.debtAmt, GAS_COMPENSATION
        );
        // tx execution
        borrowerOperationsProxy.openTrove(
            troveManagerBeaconProxy,
            user1,
            vars.maxFeePercentage,
            vars.collAmt,
            vars.debtAmt,
            vars.upperHint,
            vars.lowerHint
        );

        // state after
        vars.rewardManagerDebtAmtAfter = debtTokenProxy.balanceOf(satoshiCore.rewardManager());
        vars.gasPoolDebtAmtAfter = debtTokenProxy.balanceOf(address(gasPool));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.rewardManagerDebtAmtAfter, vars.rewardManagerDebtAmtBefore + vars.borrowingFee);
        assertEq(vars.gasPoolDebtAmtAfter, vars.gasPoolDebtAmtBefore + GAS_COMPENSATION);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.debtAmt);
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore - vars.collAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.collAmt);

        vm.stopPrank();
    }

    function testAddColl() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e8;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;

        vm.startPrank(user1);
        deal(address(collateral), user1, vars.addCollAmt);
        collateral.approve(address(borrowerOperationsProxy), vars.addCollAmt);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.addColl(troveManagerBeaconProxy, user1, vars.addCollAmt, vars.upperHint, vars.lowerHint);

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);

        vm.stopPrank();
    }

    function testwithdrawColl() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e8;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;

        vm.startPrank(user1);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.withdrawColl(
            troveManagerBeaconProxy, user1, vars.withdrawCollAmt, vars.upperHint, vars.lowerHint
        );

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);

        vm.stopPrank();
    }

    function testWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawDebtAmt = 10000e18;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user1);

        // state before
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.withdrawDebt(
            troveManagerBeaconProxy, user1, vars.maxFeePercentage, vars.withdrawDebtAmt, vars.upperHint, vars.lowerHint
        );

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.repayDebtAmt = 5000e18;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user1);

        // state before
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.collAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.collAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.collAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.repayDebt(
            troveManagerBeaconProxy, user1, vars.repayDebtAmt, vars.upperHint, vars.lowerHint
        );

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTrove_AddCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e8;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user1);
        deal(address(collateral), user1, vars.addCollAmt);
        collateral.approve(address(borrowerOperationsProxy), vars.addCollAmt);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.adjustTrove(
            troveManagerBeaconProxy,
            user1,
            0, /* vars.maxFeePercentage */
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint
        );

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTrove_AddCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.addCollAmt = 0.5e8;
        vars.withdrawDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt + vars.addCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user1);
        deal(address(collateral), user1, vars.addCollAmt);
        collateral.approve(address(borrowerOperationsProxy), vars.addCollAmt);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.adjustTrove(
            troveManagerBeaconProxy,
            user1,
            vars.maxFeePercentage,
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint
        );

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore - vars.addCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore + vars.addCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testAdjustTrove_WithdrawCollAndRepayDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e8;
        vars.repayDebtAmt = 5000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt - vars.repayDebtAmt;

        vm.startPrank(user1);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        uint256 originalCompositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.debtAmt);
        uint256 originalBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.totalDebt = originalCompositeDebt + originalBorrowingFee - vars.repayDebtAmt;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.adjustTrove(
            troveManagerBeaconProxy,
            user1,
            0, /* vars.maxFeePercentage */
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.repayDebtAmt,
            false, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint
        );

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore - vars.repayDebtAmt);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTrove_WithdrawCollAndWithdrawDebt() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vars.withdrawCollAmt = 0.5e8;
        vars.withdrawDebtAmt = 2000e18;
        vars.totalCollAmt = vars.collAmt - vars.withdrawCollAmt;
        vars.totalNetDebtAmt = vars.debtAmt + vars.withdrawDebtAmt;

        vm.startPrank(user1);

        // state before
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtBefore = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check NodeAdded event
        vars.compositeDebt = borrowerOperationsProxy.getCompositeDebt(vars.totalNetDebtAmt);
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.totalNetDebtAmt);
        vars.totalDebt = vars.compositeDebt + vars.borrowingFee;
        vars.NICR = SatoshiMath._computeNominalCR(vars.totalCollAmt, vars.totalDebt);
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeAdded(user1, vars.NICR);

        // check TotalStakesUpdated event
        vars.stake = vars.totalCollAmt;
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TotalStakesUpdated(vars.stake);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, vars.totalDebt, vars.totalCollAmt, vars.stake, TroveManagerOperation.adjust);

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
        borrowerOperationsProxy.adjustTrove(
            troveManagerBeaconProxy,
            user1,
            vars.maxFeePercentage,
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint
        );

        // state after
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();

        // check state
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore + vars.withdrawCollAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.withdrawCollAmt);
        assertEq(vars.userDebtAmtAfter, vars.userDebtAmtBefore + vars.withdrawDebtAmt);
        uint256 newBorrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.withdrawDebtAmt);
        assertEq(
            vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore + vars.withdrawDebtAmt + newBorrowingFee
        );

        vm.stopPrank();
    }

    function testCloseTrove() public {
        LocalVars memory vars;
        // pre open trove
        vars.collAmt = 1e8; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD
        vars.maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateral,
            vars.collAmt,
            vars.debtAmt,
            vars.maxFeePercentage
        );

        vm.startPrank(user1);
        //  mock user debt token balance
        vars.borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(vars.debtAmt);
        vars.repayDebtAmt = vars.debtAmt + vars.borrowingFee;
        deal(address(debtTokenProxy), user1, vars.repayDebtAmt);

        // state before
        vars.debtTokenTotalSupplyBefore = debtTokenProxy.totalSupply();
        vars.userCollAmtBefore = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtBefore = collateral.balanceOf(address(troveManagerBeaconProxy));

        /* check events emitted correctly in tx */
        // check NodeRemoved event
        vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
        emit NodeRemoved(user1);

        // check TroveUpdated event
        vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
        emit TroveUpdated(user1, 0, 0, 0, TroveManagerOperation.close);

        // tx execution
        borrowerOperationsProxy.closeTrove(troveManagerBeaconProxy, user1);

        // state after
        vars.userDebtAmtAfter = debtTokenProxy.balanceOf(user1);
        vars.debtTokenTotalSupplyAfter = debtTokenProxy.totalSupply();
        vars.userCollAmtAfter = collateral.balanceOf(user1);
        vars.troveManagerCollateralAmtAfter = collateral.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(vars.userDebtAmtAfter, 0);
        assertEq(vars.debtTokenTotalSupplyAfter, vars.debtTokenTotalSupplyBefore - vars.repayDebtAmt - GAS_COMPENSATION);
        assertEq(vars.userCollAmtAfter, vars.userCollAmtBefore + vars.collAmt);
        assertEq(vars.troveManagerCollateralAmtAfter, vars.troveManagerCollateralAmtBefore - vars.collAmt);

        vm.stopPrank();
    }
}
