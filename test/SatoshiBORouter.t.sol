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
import {DeployBase} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";

contract SatoshiBORouterTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IWETH weth;
    IMultiCollateralHintHelpers hintHelpers;
    ISatoshiBORouter satoshiBORouter;
    address user1;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, roundData, collateralMock, deploymentParams
        );

        // deploy helper contracts
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
        weth = IWETH(_deployWETH(DEPLOYER));
        satoshiBORouter = ISatoshiBORouter(_deploySatoshiBORouter(DEPLOYER, weth));
    }

    function testOpenTrove() public {
        // open trove params
        uint256 collateralAmt = 1e18; // price defined in `TestConfig.roundData`
        uint256 debtAmt = 10000e18; // 10000 USD
        uint256 maxFeePercentage = 0.05e18; // 5%

        vm.startPrank(user1);
        deal(address(collateralMock), user1, 1e18);
        collateralMock.approve(address(satoshiBORouter), 1e18);

        // user1 set delegate approval for satoshiBORouter 
        borrowerOperationsProxy.setDelegateApproval(address(satoshiBORouter), true);

        // state before
        uint256 feeReceiverDebtAmtBefore = debtToken.balanceOf(satoshiCore.feeReceiver());
        uint256 gasPoolDebtAmtBefore = debtToken.balanceOf(address(gasPool));
        uint256 user1DebtAmtBefore = debtToken.balanceOf(user1);
        uint256 user1CollateralAmtBefore = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtBefore = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        uint256 borrowingFee = troveManagerBeaconProxy.getBorrowingFeeWithDecay(debtAmt);

        // {} too avoid stack too deep error
        {
            /* check events emitted correctly in tx */
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

        {
            // calc hint
            (address upperHint, address lowerHint) = HintLib.getHint(
                hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, collateralAmt, debtAmt, GAS_COMPENSATION
            );
            // tx execution
            satoshiBORouter.openTrove(
                troveManagerBeaconProxy, user1, maxFeePercentage, collateralAmt, debtAmt, upperHint, lowerHint
            );
        }

        // state after
        uint256 feeReceiverDebtAmtAfter = debtToken.balanceOf(satoshiCore.feeReceiver());
        uint256 gasPoolDebtAmtAfter = debtToken.balanceOf(address(gasPool));
        uint256 user1DebtAmtAfter = debtToken.balanceOf(user1);
        uint256 user1CollateralAmtAfter = collateralMock.balanceOf(user1);
        uint256 troveManagerCollateralAmtAfter = collateralMock.balanceOf(address(troveManagerBeaconProxy));

        // check state
        assertEq(feeReceiverDebtAmtAfter, feeReceiverDebtAmtBefore + borrowingFee);
        assertEq(gasPoolDebtAmtAfter, gasPoolDebtAmtBefore + GAS_COMPENSATION);
        assertEq(user1DebtAmtAfter, user1DebtAmtBefore + debtAmt);
        assertEq(user1CollateralAmtAfter, user1CollateralAmtBefore - collateralAmt);
        assertEq(troveManagerCollateralAmtAfter, troveManagerCollateralAmtBefore + collateralAmt);

        vm.stopPrank();
    }
}
