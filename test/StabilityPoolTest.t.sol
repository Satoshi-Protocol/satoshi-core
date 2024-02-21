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
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";

contract StabilityPoolTest is Test, DeployBase, TroveBase, TestConfig, Events {
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

    // deposit to SP and check the stake amount in SP
    function testProvideToSP() public {
        // open trove
        _openTrove(user1, 1e18, 10000e18);
        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtBefore, 0);

        // deposit to SP
        _provideToSP(user1, 200e18);
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtAfter, 200e18);
    }

    // withdraw from SP and check the stake amount in SP
    function testWithdrawFromSPFull() public {
        // open trove
        _openTrove(user1, 1e18, 10000e18);

        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtBefore, 0);

        // deposit to SP
        _provideToSP(user1, 200e18);

        vm.warp(block.timestamp + 1);

        // withdraw from SP
        _withdrawFromSP(user1, 200e18);
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtAfter, 0);
    }

    function testLiquidateInNormalModeICRLessThanMCR() public {
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 20500
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        (, uint256 user2DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (, uint256 user3DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);

        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        // check user2 and user3's Troves are liquidated (Troves are closed)
        assertFalse(sortedTrovesBeaconProxy.contains(user2));
        assertFalse(sortedTrovesBeaconProxy.contains(user3));

        // Confirm SP has decreased
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertTrue(stabilityPoolDebtAfter < stabilityPoolDebtBefore);
        assertEq(stabilityPoolDebtAfter, stabilityPoolDebtBefore - user2DebtBefore - user3DebtBefore);

        // check the collateral gain by user1
        // uint256[] memory collateralGains = stabilityPoolProxy.getDepositorCollateralGain(user1);
        // console.log("collateralGains", collateralGains[0]);
        // assertEq(collateralGains[0], (user2CollBefore + user3CollBefore) * 995 / 1000);
    }

    function testLiquidateInNormalModeICRLessThan100() public {
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 10000_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        (, uint256 user2DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (, uint256 user3DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);

        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        // check user2 and user3's Troves are liquidated (Troves are closed)
        assertFalse(sortedTrovesBeaconProxy.contains(user2));
        assertFalse(sortedTrovesBeaconProxy.contains(user3));

        // Confirm SP has decreased
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertTrue(stabilityPoolDebtAfter < stabilityPoolDebtBefore);
        assertEq(stabilityPoolDebtAfter, stabilityPoolDebtBefore - user2DebtBefore - user3DebtBefore);
    }

    function testCorrectUpdateSnapshot() public {
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 2 toves opened
        _openTrove(user2, 1e18, 20000e18);
        _openTrove(user3, 1e18, 20000e18);

        _openTrove(user4, 1e18, 100e18);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 20500
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user3);

        uint256 PBefore = stabilityPoolProxy.P();
        uint256 SBefore = stabilityPoolProxy.epochToScaleToSums(0, 0, 0);
        uint256 GBefore = stabilityPoolProxy.epochToScaleToG(0, 0);
        assertTrue(PBefore > 0);
        assertTrue(SBefore > 0);

        // user4 before snapshot
        (uint256 user4PBefore, uint256 user4GBefore,,) = stabilityPoolProxy.depositSnapshots(user4);
        assertEq(user4PBefore, 0);
        assertEq(user4GBefore, 0);

        // user4 deposit
        _provideToSP(user4, 100e18);

        // user4 after snapshot
        (uint256 user4PAfter, uint256 user4GAfter,,) = stabilityPoolProxy.depositSnapshots(user4);
        assertEq(user4PAfter, PBefore);
        assertEq(user4GAfter, GBefore);
    }

    function testTryToProvideMoreThanBlanace() public {
        _openTrove(user1, 1e18, 100e18);

        // attempt to provide 1 wei more than his balance
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        TroveBase.provideToSP(stabilityPoolProxy, user1, 100e18 + 1);
    }

    function testTryToProvide0Blanace() public {
        _openTrove(user1, 1e18, 100e18);

        // attempt to provide 0 balance
        vm.expectRevert("StabilityPool: Amount must be non-zero");
        TroveBase.provideToSP(stabilityPoolProxy, user1, 0);
    }

    function testClaimCollGain() public {
        // whale opens trove
        _openTrove(user1, 100e18, 185000e18);
        _provideToSP(user1, 100000e18);
        // 1 tove opened
        _openTrove(user2, 1e18, 20000e18);

        // price drops: user2's and user3's Troves fall below MCR, whale doesn't
        _updateRoundData(
            RoundData({
                answer: 20500_00_000_000, // 10000
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 2
            })
        );

        // liquidate user2
        liquidationManagerProxy.liquidate(troveManagerBeaconProxy, user2);

        uint256[] memory user1CollGain = stabilityPoolProxy.getDepositorCollateralGain(user1);

        // claim collateral gain
        _claimCollateralGains(user1);

        // check the collateral gain is as expected
        assertEq(user1CollGain[0], collateralMock.balanceOf(user1));
    }
}
