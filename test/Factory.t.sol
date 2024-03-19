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

contract FactoryTest is Test, DeployBase, TroveBase, TestConfig, Events {
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

    function test_setRewardrate() public {
        uint128 maxRewardRate = factory.maxRewardRate();
        vm.prank(OWNER);
        uint128[] memory numerator = new uint128[](1);
        numerator[0] = 1;
        factory.setRewardRate(numerator, 2);
        uint128 rewardRateAfter = troveManagerBeaconProxy.rewardRate();
        assertEq(rewardRateAfter, maxRewardRate / 2);
    }

    function test_setRewardRateAndCheckOSHIAmount() public {
        uint128[] memory numerator = new uint128[](1);

        vm.prank(OWNER);
        numerator[0] = 0;
        factory.setRewardRate(numerator, 1);
        _openTrove(user1, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.claimableReward(user1), 0);
        vm.warp(block.timestamp + 10000);
        assertEq(troveManagerBeaconProxy.claimableReward(user1), 0);

        uint128 maxRewardRate = factory.maxRewardRate();
        vm.startPrank(OWNER);
        numerator[0] = 1;
        factory.setRewardRate(numerator, 1);
        uint128 rewardRateAfter = troveManagerBeaconProxy.rewardRate();
        assertEq(rewardRateAfter, maxRewardRate);
        vm.stopPrank();

        vm.warp(block.timestamp + 10000);
        // check oshi reward in TM
        assertApproxEqAbs(troveManagerBeaconProxy.claimableReward(user1), 10000 * rewardRateAfter, 100000);
    }
}
