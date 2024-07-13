// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console, Vm} from "forge-std/Test.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER,
    OWNER,
    GUARDIAN,
    GAS_COMPENSATION,
    TestConfig,
    REWARD_MANAGER,
    FEE_RECEIVER,
    _1_MILLION
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS, REWARD_MANAGER_GAIN, REWARD_MANAGER_PRECISION} from "./TestConfig.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";

contract SatoshiCoreTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;

    function setUp() public override {
        super.setUp();

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
    }

    function testCorrectOwner() public {
        assertEq(satoshiCore.owner(), OWNER);
    }

    function testPause() public {
        vm.startPrank(OWNER);
        assert(!satoshiCore.paused());
        satoshiCore.setPaused(true);
        assert(satoshiCore.paused());
        satoshiCore.setPaused(false);
        assert(!satoshiCore.paused());
        vm.stopPrank();
    }

    function testSetFeeReceiver() public {
        vm.startPrank(OWNER);
        assertEq(satoshiCore.feeReceiver(), FEE_RECEIVER);
        satoshiCore.setFeeReceiver(DEPLOYER);
        assertEq(satoshiCore.feeReceiver(), DEPLOYER);
        vm.stopPrank();
    }

    function testSetRewardManager() public {
        vm.startPrank(OWNER);
        assertEq(satoshiCore.rewardManager(), address(rewardManagerProxy));
        satoshiCore.setRewardManager(DEPLOYER);
        assertEq(satoshiCore.rewardManager(), DEPLOYER);
        vm.stopPrank();
    }

    function testSetGuardian() public {
        vm.startPrank(OWNER);
        assertEq(satoshiCore.guardian(), GUARDIAN);
        satoshiCore.setGuardian(OWNER);
        assertEq(satoshiCore.guardian(), OWNER);
        vm.stopPrank();
    }

    function testOwnershipTransfer() public {
        vm.startPrank(OWNER);
        assertEq(satoshiCore.pendingOwner(), address(0));
        satoshiCore.commitTransferOwnership(DEPLOYER);
        assertEq(satoshiCore.pendingOwner(), DEPLOYER);
        vm.stopPrank();
        vm.startPrank(DEPLOYER);
        vm.warp(block.timestamp + satoshiCore.OWNERSHIP_TRANSFER_DELAY());
        satoshiCore.acceptTransferOwnership();
        assertEq(satoshiCore.owner(), DEPLOYER);
        assertEq(satoshiCore.pendingOwner(), address(0));
        vm.stopPrank();
        vm.startPrank(DEPLOYER);
        satoshiCore.commitTransferOwnership(OWNER);
        assertEq(satoshiCore.pendingOwner(), OWNER);
        satoshiCore.revokeTransferOwnership();
        assertEq(satoshiCore.pendingOwner(), address(0));
        vm.stopPrank();
    }
}
