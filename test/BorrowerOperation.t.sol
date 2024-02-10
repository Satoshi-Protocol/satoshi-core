// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase} from "./DeployBase.t.sol";
import {HintLib} from "./HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./TroveBase.t.sol";

contract BorrowerOperationTest is Test, DeployBase, TroveBase, TestConfig {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    address user1;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, roundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        _deployHintHelpers(DEPLOYER);
    }

    function testOpenTrove() public {
        // open trove params
        uint256 collateralAmt = 1e18; // price defined in `TestConfig.roundData`
        uint256 debtAmt = 10000e18; // 10000 USD
        uint256 maxFeePercentage = 0.05e18; // 5%

        vm.startPrank(user1);
        deal(address(collateralMock), user1, 1e18);
        collateralMock.approve(address(borrowerOperationsProxy), 1e18);

        // state before
        uint256 feeReceiverDebtAmtBefore = debtToken.balanceOf(satoshiCore.feeReceiver());
        uint256 gasPoolDebtAmtBefore = debtToken.balanceOf(address(gasPool));
        uint256 user1DebtAmtBefore = debtToken.balanceOf(user1);
        uint256 user1CollateralAmtBefore = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtBefore = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        uint256 borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(debtAmt);

        // {} too avoid stack too deep error
        {
            // check BorrowingFeePaid event
            vm.expectEmit(true, true, true, true, address(borrowerOperationsProxy));
            emit BorrowingFeePaid(user1, collateralMock, borrowingFee);

            // check TotalStakesUpdated event
            uint256 stake = collateralAmt;
            vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
            emit TotalStakesUpdated(stake);

            // check NodeAdded event
            uint256 compositeDebt = borrowerOperationsProxy.getCompositeDebt(debtAmt);
            uint256 totalDebt = compositeDebt + borrowingFee;
            uint256 NICR = SatoshiMath._computeNominalCR(collateralAmt, totalDebt);
            vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
            emit NodeAdded(user1, NICR);

            // check NewDeployment event
            vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
            emit TroveUpdated(user1, totalDebt, collateralAmt, stake, TroveManagerOperation.open);
        }

        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, collateralAmt, debtAmt, GAS_COMPENSATION
        );
        // tx execution
        borrowerOperationsProxy.openTrove(
            troveManagerBeaconProxy, user1, maxFeePercentage, collateralAmt, debtAmt, upperHint, lowerHint
        );

        // state after
        uint256 feeReceiverDebtAmtAfter = debtToken.balanceOf(satoshiCore.feeReceiver());
        uint256 gasPoolDebtAmtAfter = debtToken.balanceOf(address(gasPool));
        uint256 user1DebtAmtAfter = debtToken.balanceOf(user1);
        uint256 user1CollateralAmtAfter = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtAfter = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assert(feeReceiverDebtAmtAfter == feeReceiverDebtAmtBefore + borrowingFee);
        assert(gasPoolDebtAmtAfter == gasPoolDebtAmtBefore + GAS_COMPENSATION);
        assert(user1DebtAmtAfter == user1DebtAmtBefore + debtAmt);
        assert(user1CollateralAmtAfter == user1CollateralAmtBefore - collateralAmt);
        assert(troveManagerCollateralAmtAfter == troveManagerCollateralAmtBefore + collateralAmt);

        vm.stopPrank();
    }

    function testAddColl() public {
        // pre open trove
        uint256 collateralAmt = 1e18; // price defined in `TestConfig.roundData`
        uint256 debtAmt = 10000e18; // 10000 USD
        uint256 maxFeePercentage = 0.05e18; // 5%
        TroveBase.openTrove(
            borrowerOperationsProxy,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            hintHelpers,
            GAS_COMPENSATION,
            user1,
            user1,
            collateralMock,
            collateralAmt,
            debtAmt,
            maxFeePercentage
        );

        uint256 addCollAmt = 0.5e18;
        vm.startPrank(user1);
        deal(address(collateralMock), user1, 0.5e18);
        collateralMock.approve(address(borrowerOperationsProxy), 0.5e18);

        // state before
        uint256 user1CollateralAmtBefore = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtBefore = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        // {} too avoid stack too deep error
        {
            // check NodeRemoved event
            vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
            emit NodeRemoved(user1);

            // check NodeAdded event
            uint256 compositeDebt = borrowerOperationsProxy.getCompositeDebt(debtAmt);
            uint256 borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(debtAmt);
            uint256 totalDebt = compositeDebt + borrowingFee;
            uint256 NICR = SatoshiMath._computeNominalCR(collateralAmt + addCollAmt, totalDebt);
            vm.expectEmit(true, true, true, true, address(sortedTrovesBeaconProxy));
            emit NodeAdded(user1, NICR);

            // check TotalStakesUpdated event
            uint256 stake = collateralAmt + addCollAmt;
            vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
            emit TotalStakesUpdated(stake);

            // check TroveUpdated event
            vm.expectEmit(true, true, true, true, address(troveManagerBeaconProxy));
            emit TroveUpdated(user1, totalDebt, collateralAmt + addCollAmt, stake, TroveManagerOperation.adjust);
        }

        // calc hint
        uint256 totalCollAmt = collateralAmt + addCollAmt;
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, totalCollAmt, debtAmt, GAS_COMPENSATION
        );
        // tx execution
        borrowerOperationsProxy.addColl(troveManagerBeaconProxy, user1, addCollAmt, upperHint, lowerHint);

        // state after
        uint256 user1CollateralAmtAfter = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtAfter = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assert(user1CollateralAmtAfter == user1CollateralAmtBefore - addCollAmt);
        assert(troveManagerCollateralAmtAfter == troveManagerCollateralAmtBefore + addCollAmt);

        vm.stopPrank();
    }

    function testwithdrawColl() public {

    }

    function testWithdrawDebt() public {

    }

    function testRepayDebt() public {

    }

    function testAdjustTrove() public {

    }

    function testCloseTrove() public {

    }

    /* copied from contracts for event testing */
    event TroveUpdated(
        address indexed _borrower, uint256 _debt, uint256 _coll, uint256 _stake, TroveManagerOperation _operation
    );
    event BorrowingFeePaid(address indexed borrower, IERC20 indexed collateralToken, uint256 amount);
    event TotalStakesUpdated(uint256 _newTotalStakes);
    event NodeAdded(address _id, uint256 _NICR);
    event NodeRemoved(address _id);
}
