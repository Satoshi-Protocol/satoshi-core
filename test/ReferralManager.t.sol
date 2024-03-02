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
import {IReferralManager} from "../src/helpers/interfaces/IReferralManager.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";

contract ReferralManagerTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IWETH weth;
    IMultiCollateralHintHelpers hintHelpers;
    ISatoshiBORouter satoshiBORouter;
    IReferralManager referralManager;
    address user;
    address referrer;

    function setUp() public override {
        super.setUp();

        // testing user
        user = vm.addr(1);
        referrer = vm.addr(2);

        // use WETH as collateral
        weth = IWETH(_deployWETH(DEPLOYER));
        deal(address(weth), 10000e18);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, weth, deploymentParams
        );

        // deploy helper contracts
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        uint64 nonce = vm.getNonce(DEPLOYER);
        address cpSatoshiBORouterAddr = vm.computeCreateAddress(DEPLOYER, nonce);
        address cpReferralManagerAddr = vm.computeCreateAddress(DEPLOYER, ++nonce);
        satoshiBORouter =
            ISatoshiBORouter(_deploySatoshiBORouter(DEPLOYER, IReferralManager(cpReferralManagerAddr), weth));
        referralManager = IReferralManager(_deployReferralManager(DEPLOYER, ISatoshiBORouter(cpSatoshiBORouterAddr)));

        // user set delegate approval for satoshiBORouter
        vm.startPrank(user);
        borrowerOperationsProxy.setDelegateApproval(address(satoshiBORouter), true);
        vm.stopPrank();
    }

    function testOpenTroveReferral() public {
        LocalVars memory vars;
        // open trove params
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD

        vm.startPrank(user);
        deal(user, 1e18);

        // state before
        uint256 totalPointsBefore = referralManager.getTotalPoints();
        uint256 referrerPointsBefore = referralManager.getPoints(referrer);

        /* check events emitted correctly in tx */
        // check ExecuteReferral event
        vm.expectEmit(true, true, true, true, address(referralManager));
        emit ExecuteReferral(user, referrer, vars.debtAmt);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, vars.collAmt, vars.debtAmt, GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.openTrove{value: vars.collAmt}(
            troveManagerBeaconProxy,
            user,
            0.05e18, /* vars.maxFeePercentage 5% */
            vars.collAmt,
            vars.debtAmt,
            vars.upperHint,
            vars.lowerHint,
            referrer
        );

        // state after
        uint256 totalPointsAfter = referralManager.getTotalPoints();
        uint256 referrerPointsAfter = referralManager.getPoints(referrer);

        // check state
        assertEq(totalPointsAfter, totalPointsBefore + vars.debtAmt);
        assertEq(referrerPointsAfter, referrerPointsBefore + vars.debtAmt);

        vm.stopPrank();
    }

    function testWithdrawDebtReferral() public {
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
        uint256 totalPointsBefore = referralManager.getTotalPoints();
        uint256 referrerPointsBefore = referralManager.getPoints(referrer);

        /* check events emitted correctly in tx */
        // check ExecuteReferral event
        vm.expectEmit(true, true, true, true, address(referralManager));
        emit ExecuteReferral(user, referrer, vars.withdrawDebtAmt);

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
            user,
            vars.maxFeePercentage,
            vars.withdrawDebtAmt,
            vars.upperHint,
            vars.lowerHint,
            referrer
        );

        // state after
        uint256 totalPointsAfter = referralManager.getTotalPoints();
        uint256 referrerPointsAfter = referralManager.getPoints(referrer);

        // check state
        assertEq(totalPointsAfter, totalPointsBefore + vars.withdrawDebtAmt);
        assertEq(referrerPointsAfter, referrerPointsBefore + vars.withdrawDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveReferral_AddCollAndWithdrawDebt() public {
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
        uint256 totalPointsBefore = referralManager.getTotalPoints();
        uint256 referrerPointsBefore = referralManager.getPoints(referrer);

        /* check events emitted correctly in tx */
        // check ExecuteReferral event
        vm.expectEmit(true, true, true, true, address(referralManager));
        emit ExecuteReferral(user, referrer, vars.withdrawDebtAmt);

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
            user,
            vars.maxFeePercentage,
            vars.addCollAmt,
            0, /* collWithdrawalAmt */
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            referrer
        );

        // state after
        uint256 totalPointsAfter = referralManager.getTotalPoints();
        uint256 referrerPointsAfter = referralManager.getPoints(referrer);

        // check state
        assertEq(totalPointsAfter, totalPointsBefore + vars.withdrawDebtAmt);
        assertEq(referrerPointsAfter, referrerPointsBefore + vars.withdrawDebtAmt);

        vm.stopPrank();
    }

    function testAdjustTroveReferral_WithdrawCollAndWithdrawDebt() public {
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
        uint256 totalPointsBefore = referralManager.getTotalPoints();
        uint256 referrerPointsBefore = referralManager.getPoints(referrer);

        /* check events emitted correctly in tx */
        // check ExecuteReferral event
        vm.expectEmit(true, true, true, true, address(referralManager));
        emit ExecuteReferral(user, referrer, vars.withdrawDebtAmt);

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
            user,
            vars.maxFeePercentage,
            0, /* collAdditionAmt */
            vars.withdrawCollAmt,
            vars.withdrawDebtAmt,
            true, /* debtIncrease */
            vars.upperHint,
            vars.lowerHint,
            referrer
        );

        // state after
        uint256 totalPointsAfter = referralManager.getTotalPoints();
        uint256 referrerPointsAfter = referralManager.getPoints(referrer);

        // check state
        assertEq(totalPointsAfter, totalPointsBefore + vars.withdrawDebtAmt);
        assertEq(referrerPointsAfter, referrerPointsBefore + vars.withdrawDebtAmt);

        vm.stopPrank();
    }

    function testFailExecuteReferral() public {
        vm.startPrank(user);

        referralManager.executeReferral(user, user, 10000);

        vm.stopPrank();
    }

    function testOpenTroveNotInReferralTime() public {
        // reset referral start and end time
        vm.startPrank(DEPLOYER);
        referralManager.setStartTimestamp(0);
        referralManager.setEndTimestamp(0);
        vm.stopPrank();

        LocalVars memory vars;
        // open trove params
        vars.collAmt = 1e18; // price defined in `TestConfig.roundData`
        vars.debtAmt = 10000e18; // 10000 USD

        vm.startPrank(user);
        deal(user, 1e18);

        // state before
        uint256 totalPointsBefore = referralManager.getTotalPoints();
        uint256 referrerPointsBefore = referralManager.getPoints(referrer);

        // calc hint
        (vars.upperHint, vars.lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, vars.collAmt, vars.debtAmt, GAS_COMPENSATION
        );
        // tx execution
        satoshiBORouter.openTrove{value: vars.collAmt}(
            troveManagerBeaconProxy,
            user,
            0.05e18, /* vars.maxFeePercentage 5% */
            vars.collAmt,
            vars.debtAmt,
            vars.upperHint,
            vars.lowerHint,
            referrer
        );

        // state after
        uint256 totalPointsAfter = referralManager.getTotalPoints();
        uint256 referrerPointsAfter = referralManager.getPoints(referrer);

        // check state
        assertEq(totalPointsAfter, totalPointsBefore);
        assertEq(referrerPointsAfter, referrerPointsBefore);

        vm.stopPrank();
    }
}
