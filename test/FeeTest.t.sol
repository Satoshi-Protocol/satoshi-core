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

contract FeeTest is Test, DeployBase, TroveBase, TestConfig, Events {
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

    function _provideToSP(address caller, uint256 amount) internal {
        TroveBase.provideToSP(stabilityPoolProxy, caller, amount);
    }

    function _withdrawFromSP(address caller, uint256 amount) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy, caller, amount);
    }

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function _transfer(address caller, address token, address to, uint256 amount) internal {
        vm.startPrank(caller);
        IERC20(token).transfer(to, amount);
        vm.stopPrank();
    }

    function _claimCollateralGains(address caller) internal {
        vm.startPrank(caller);
        uint256[] memory collateralIndexes = new uint256[](1);
        collateralIndexes[0] = 0;
        stabilityPoolProxy.claimCollateralGains(caller, collateralIndexes);
        vm.stopPrank();
    }

    function test_AccrueInterstCorrect() public {
        // open a trove
        _openTrove(user1, 1e18, 1000e18);
        (uint256 user1CollBefore, uint256 user1DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);

        // 365 days later
        vm.warp(block.timestamp + 365 days);

        (uint256 user1CollAfter, uint256 user1DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        assertEq(user1CollAfter, user1CollBefore);

        // check the debt
        uint256 expectedDebt = user1DebtBefore * (10000 + INTEREST_RATE_IN_BPS) / 10000;
        uint256 delta = SatoshiMath._getAbsoluteDifference(expectedDebt, user1DebtAfter);
        assert(delta < 1000);
    }

    function test_AccrueInterst2yCorrect() public {
        // open a trove
        _openTrove(user1, 1e18, 10000e18);
        _transfer(user1, address(debtToken), user2, 60e18);
        _transfer(user1, address(debtToken), user3, 60e18);
        _transfer(user1, address(debtToken), user4, 60e18);
        (uint256 user1CollBefore, uint256 user1DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);

        vm.warp(block.timestamp + 365 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user2, 1e18, 60e18);

        vm.warp(block.timestamp + 65 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user3, 1e18, 60e18);

        vm.warp(block.timestamp + 100 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user4, 1e18, 60e18);

        vm.warp(block.timestamp + 100 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user5, 1e18, 60e18);

        vm.warp(block.timestamp + 10 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _closeTrove(user2);

        // 365 days later
        vm.warp(block.timestamp + 90 days);

        (uint256 user1CollAfter, uint256 user1DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        assertEq(user1CollAfter, user1CollBefore);
        uint256 expectedSimpleDebt = user1DebtBefore * (10000 + 2 * INTEREST_RATE_IN_BPS) / 10000;
        assert(user1DebtAfter > user1DebtBefore);
        assert(user1DebtAfter > expectedSimpleDebt);

        // console.log("user1DebtBefore", user1DebtBefore);
        // console.log("user1DebtAfter ", user1DebtAfter);
        // check the debt
        // uint256 delta = SatoshiMath._getAbsoluteDifference(expectedDebt, user1DebtAfter);
        // assert(delta < 1000);
    }

    function test_AccrueInterst2TroveCorrect() public {
        // open a trove
        _openTrove(user1, 1e18, 1000e18);
        _openTrove(user2, 1e18, 1000e18);
        (uint256 user1CollBefore, uint256 user1DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollBefore, uint256 user2DebtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);

        // 365 days later
        vm.warp(block.timestamp + 365 days);

        (uint256 user1CollAfter, uint256 user1DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user1);
        (uint256 user2CollAfter, uint256 user2DebtAfter) = troveManagerBeaconProxy.getTroveCollAndDebt(user2);
        assertEq(user1CollAfter, user1CollBefore);
        assertEq(user2CollAfter, user2CollBefore);

        // check the debt
        uint256 expectedDebt = (user1DebtBefore + user2DebtBefore) * (10000 + INTEREST_RATE_IN_BPS) / 10000;
        uint256 delta = SatoshiMath._getAbsoluteDifference(expectedDebt, user1DebtAfter + user2DebtAfter);
        assert(delta < 1000);
    }

    function test_CollectInterestToRewardManager() public {
        _openTrove(user1, 1e18, 1000e18);
        // 365 days later
        vm.warp(block.timestamp + 365 days);
        _updateRoundData(
            RoundData({
                answer: 40000_00_000_000,
                startedAt: block.timestamp,
                updatedAt: block.timestamp,
                answeredInRound: 1
            })
        );
        _openTrove(user2, 1e18, 50e18);
        uint256 expectedMintingFee = 5e18 + 0.25e18;
        uint256 expectedDebt = 1010e18 * INTEREST_RATE_IN_BPS / 10000;
        uint256 delta = SatoshiMath._getAbsoluteDifference(
            debtToken.balanceOf(address(rewardManagerProxy)), expectedMintingFee + expectedDebt
        );
        assert(delta < 1000);
    }

    function test_OneTimeBorrowFee1() public {
        _openTrove(user1, 1e18, 1000e18);
        // 365 days later
        uint256 delta = SatoshiMath._getAbsoluteDifference(debtToken.balanceOf(address(rewardManagerProxy)), 5e18);
        require(delta == 0, "delta != 0");
    }
}
