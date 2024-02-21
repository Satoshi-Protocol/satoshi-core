// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LiquidationVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";

contract LiquidateTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);

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

    function _convertDebtToColl(uint256 debt, uint256 price) internal pure returns (uint256) {
        return debt * 1e18 / price;
    }
    
    function test_LiquidateICRLessThan100InRecoveryMode() public {
        LiquidationVars memory vars;
        // open troves
        _openTrove(user1, 1e18, 10000e18);
        _openTrove(user2, 1e18, 10000e18);
        _openTrove(user3, 1e18, 10000e18);
        
        // reducing TCR below 150%, and all Troves below 100% ICR
        _updateRoundData(
            RoundData({
                answer: 10000_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );

        (uint256 coll1, uint256 debt1) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 coll2Before, uint256 debt2Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (uint256 coll3Before, uint256 debt3Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        vars.collToRedistribute = (coll1 - coll1 / 200);
        vars.debtToRedistribute = debt1;
        vars.collGasCompensation = coll1 / 200;
        vars.debtGasCompensation = GAS_COMPENSATION;

        vm.startPrank(user4);
        // redistibute the collateral and debt
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user1);

        (uint256 coll2, uint256 debt2) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (uint256 coll3, uint256 debt3) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);

        assertEq(coll2, coll2Before + vars.collToRedistribute / 2);
        assertEq(debt2, debt2Before + vars.debtToRedistribute / 2);
        assertEq(coll3, coll3Before + vars.collToRedistribute / 2);
        assertEq(debt3, debt3Before + vars.debtToRedistribute / 2);

        // check user4 gets the reward for liquidation
        assertEq(collateralMock.balanceOf(user4), vars.collGasCompensation);
        assertEq(debtToken.balanceOf(user4), vars.debtGasCompensation);
    }

    function test_LiquidateSPNotEnoughInNormalMode() public {
        LiquidationVars memory vars;
        // open troves
        _openTrove(user1, 1000e18, 10000e18);
        _openTrove(user2, 1e18, 10000e18);
        _openTrove(user3, 1e18, 10000e18);
        _provideToSP(user1, 5000e18);

        // price drop
        _updateRoundData(
            RoundData({
                answer: 10000_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );

        uint256 user1ExpectedDebt;
        uint256 user3ExpectedDebt;
        uint256 user1ExpectedColl;
        uint256 user3ExpectedColl;
        {
            (uint256 coll1Before, uint256 debt1Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
            (uint256 coll2Before, uint256 debt2Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
            (uint256 coll3Before, uint256 debt3Before) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
            vars.collGasCompensation = coll2Before / 200;
            vars.debtGasCompensation = GAS_COMPENSATION;
            vars.debtToOffset = stabilityPoolProxy.getTotalDebtTokenDeposits();
            vars.debtToRedistribute = debt2Before - vars.debtToOffset;
            uint256 collToLiquidate = coll2Before - vars.collGasCompensation;
            vars.collToSendToSP = (collToLiquidate * vars.debtToOffset) / debt2Before;
            vars.collToRedistribute = collToLiquidate - vars.collToSendToSP;
            user1ExpectedDebt = debt1Before + vars.debtToRedistribute * coll1Before / (coll1Before + coll3Before);
            user3ExpectedDebt = debt3Before + vars.debtToRedistribute * coll3Before / (coll1Before + coll3Before);
            user1ExpectedColl = coll1Before + vars.collToRedistribute * coll1Before / (coll1Before + coll3Before);
            user3ExpectedColl = coll3Before + vars.collToRedistribute * coll3Before / (coll1Before + coll3Before);
        }

        vm.prank(user4);
        // SP will aborb the debt first, then the rest will be redistributed to all of the Troves
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);

        // check user2 closed
        assertFalse(sortedTrovesBeaconProxy.contains(user2));

        (uint256 coll1, uint256 debt1) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 coll3, uint256 debt3) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);

        // check user4 gets the reward for liquidation
        assertEq(collateralMock.balanceOf(user4), vars.collGasCompensation);
        assertEq(debtToken.balanceOf(user4), vars.debtGasCompensation);
        
        // check redistribute the remaining debt to all Troves
        assertTrue(SatoshiMath._approximatelyEqual(debt1, user1ExpectedDebt, 1000));
        assertTrue(SatoshiMath._approximatelyEqual(debt3, user3ExpectedDebt, 1000));
        assertTrue(SatoshiMath._approximatelyEqual(coll1, user1ExpectedColl, 1000));
        assertTrue(SatoshiMath._approximatelyEqual(coll3, user3ExpectedColl, 1000));
    }

    // MCR <= ICR < 150%
    function test_LiquidateICRLargeThanMCRInRecoveryMode() public {
        LiquidationVars memory vars;
        // open troves
        _openTrove(user1, 1e18, 10020e18);
        _openTrove(user2, 1e18, 10000e18);
        _openTrove(user3, 1e18, 10000e18);
        _provideToSP(user2, 10000e18);
        _provideToSP(user3, 10000e18);
        
        // reducing TCR below 150%, and all Troves 120% ICR
        _updateRoundData(
            RoundData({
                answer: 12000_00_000_000, // 12000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );

        // check is in recovery mode
        uint256 TCR = borrowerOperationsProxy.getTCR();
        bool isRecoveryMode = borrowerOperationsProxy.checkRecoveryMode(TCR);
        assertTrue(isRecoveryMode);

        uint256 price = troveManagerBeaconProxy.fetchPrice();
        uint256 MCR = troveManagerBeaconProxy.MCR();
        (uint256 coll1, uint256 debt1) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        vars.collToRedistribute = 0;
        vars.debtToRedistribute = 0;
        vars.collToSendToSP = (debt1 * MCR) / price;
        vars.debtToOffset = debt1;
        vars.collGasCompensation = vars.collToSendToSP / 200;
        vars.debtGasCompensation = GAS_COMPENSATION;
        uint256 collUser1Remaining = coll1 - vars.collToSendToSP;

        vm.startPrank(user4);
        // the user1 coll will capped at 1.1 * debt, no redistribution
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user1);

        uint256 surplusBalanceUser1 = troveManagerBeaconProxy.surplusBalances(user1);
        assertEq(surplusBalanceUser1, collUser1Remaining);

        // check user4 gets the reward for liquidation
        assertEq(collateralMock.balanceOf(user4), vars.collGasCompensation);
        assertEq(debtToken.balanceOf(user4), vars.debtGasCompensation);
    }
}
