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

contract RedeemTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 1e18; // 100%

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

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function test_getRedemptionHints() public {
        _openTrove(user1, 1e18, 13333e18);
        _openTrove(user2, 1e18, 13793e18);
        _openTrove(user3, 1e18, 20000e18);
        // user4 should be untouched by redemption after the price drop (ICR < 110%)
        // user4 should be liquidated
        _openTrove(user4, 1e18, 30000e18);

        // price drop
        _updateRoundData(
            RoundData({answer: 30500_00_000_000, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );

        uint256 price = troveManagerBeaconProxy.fetchPrice();

        // (, uint256 debt1) = troveManagerBeaconProxy
        //     .getTroveCollAndDebt(user1);
        (, uint256 debt2) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (, uint256 debt3) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        uint256 redemptionAmount = debt2 + debt3;
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount) =
            hintHelpers.getRedemptionHints(troveManagerBeaconProxy, redemptionAmount, price, 0);

        assertEq(firstRedemptionHint, user3);
        assertEq(redemptionAmount, truncatedDebtAmount);
        console.log("partialRedemptionHintNICR: ", partialRedemptionHintNICR);
    }

    function test_redeem() public {
        _openTrove(user1, 1e18, 13333e18);
        _openTrove(user2, 1e18, 13793e18);
        _openTrove(user3, 1e18, 20000e18);
        // open with a high ICR
        _openTrove(user4, 100e18, 30000e18);

        // skip bootstrapping time
        vm.warp(block.timestamp + 14 days);

        _updateRoundData(
            RoundData({answer: 40000_00_000_000, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1})
        );

        uint256 price = troveManagerBeaconProxy.fetchPrice();
        // (, uint256 debt2) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        (, uint256 debt3) = troveManagerBeaconProxy.getTroveCollAndDebt(user3);
        // (uint256 coll4, uint256 debt4) = troveManagerBeaconProxy
        //     .getTroveCollAndDebt(user4);
        uint256 redemptionAmount = debt3;
        (address firstRedemptionHint, uint256 partialRedemptionHintNICR, uint256 truncatedDebtAmount) =
            hintHelpers.getRedemptionHints(troveManagerBeaconProxy, redemptionAmount, price, 0);

        assertEq(firstRedemptionHint, user3);
        assertEq(redemptionAmount, truncatedDebtAmount);

        (address hintAddress,,) =
            hintHelpers.getApproxHint(troveManagerBeaconProxy, partialRedemptionHintNICR, 10, 31337);

        (address upperPartialRedemptionHint, address lowerPartialRedemptionHint) =
            sortedTrovesBeaconProxy.findInsertPosition(partialRedemptionHintNICR, hintAddress, hintAddress);

        // redeem
        vm.prank(user4);
        troveManagerBeaconProxy.redeemCollateral(
            redemptionAmount,
            firstRedemptionHint,
            upperPartialRedemptionHint,
            lowerPartialRedemptionHint,
            partialRedemptionHintNICR,
            0,
            maxFeePercentage
        );

        // check user3 closed, and user1, user2, user4 active
        assertFalse(sortedTrovesBeaconProxy.contains(user3));
        assertTrue(sortedTrovesBeaconProxy.contains(user1));
        assertTrue(sortedTrovesBeaconProxy.contains(user2));
        assertTrue(sortedTrovesBeaconProxy.contains(user4));
    }
}
