// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IVestingManager, VestingType} from "../src/interfaces/OSHI/IVestingManager.sol";
import {IVesting} from "../src/interfaces/OSHI/IVesting.sol";
import {IInvestorVesting} from "../src/interfaces/OSHI/IInvestorVesting.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {
    DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, REWARD_MANAGER, FEE_RECEIVER, _1_MILLION
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";

contract VestingManager is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;

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

    function test_OSHIBalance() public {
        assertEq(oshiToken.balanceOf(address(vestingManager)), 55 * _1_MILLION);
    }

    function test_deployTeamVesting() public {
        uint64 startTimestamp = uint64(block.timestamp);
        uint256 duration = 30; // 30 months
        uint256 amount = 15 * _1_MILLION;
        address beneficiary = user1;
        vm.prank(OWNER);
        address vestingAddr = vestingManager.deployVesting(beneficiary, amount, startTimestamp, VestingType.TEAM);
        IVesting vesting = IVesting(vestingAddr);
        assertEq(oshiToken.balanceOf(vestingAddr), amount);
        assertEq(address(vesting.token()), address(oshiToken));
        assertEq(vesting.owner(), user1);
        assertEq(vesting.duration(), duration * 30 days);
        // 12 months cliff
        assertEq(vesting.start(), startTimestamp + 30 days * 12);
        // 30 months vesting
        assertEq(vesting.end(), startTimestamp + 30 days * 42);
        // beneficiary transfer ownership to user2
        vm.prank(user1);
        vesting.transferOwnership(user2);
        assertEq(vesting.owner(), user2);
        // check release amount
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), 0);
        // 13 months later
        vm.warp(block.timestamp + 30 days * 13);
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), amount / duration);
        // user2 release the token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), amount / duration);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), amount / duration);
        // 30 months later
        vm.warp(block.timestamp + 30 days * 29);
        assertEq(vesting.releasable(), amount - amount / duration);
        // user2 release the token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), amount);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), amount);
    }

    function test_deployAdvisorVesting() public {
        uint64 startTimestamp = uint64(block.timestamp);
        uint256 duration = 30; // 30 months
        uint256 amount = 2 * _1_MILLION;
        address beneficiary = user1;
        vm.prank(OWNER);
        address vestingAddr = vestingManager.deployVesting(beneficiary, amount, startTimestamp, VestingType.ADVISOR);
        IVesting vesting = IVesting(vestingAddr);
        assertEq(oshiToken.balanceOf(vestingAddr), amount);
        assertEq(address(vesting.token()), address(oshiToken));
        assertEq(vesting.owner(), user1);
        assertEq(vesting.duration(), duration * 30 days);
        // 12 months cliff
        assertEq(vesting.start(), startTimestamp + 30 days * 12);
        // 30 months vesting
        assertEq(vesting.end(), startTimestamp + 30 days * 42);
        // beneficiary transfer ownership to user2
        vm.prank(user1);
        vesting.transferOwnership(user2);
        assertEq(vesting.owner(), user2);
        // check release amount
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), 0);
        // 13 months later
        vm.warp(block.timestamp + 30 days * 13);
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), amount / duration);
        // user2 release the token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), amount / duration);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), amount / duration);
        // 30 months later
        vm.warp(block.timestamp + 30 days * 29);
        assertEq(vesting.releasable(), amount - amount / duration);
        // user2 release the token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), amount);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), amount);
    }

    function test_deployInvestorVesting() public {
        uint64 startTimestamp = uint64(block.timestamp);
        uint256 duration = 24; // 24 months
        uint256 amount = 2 * _1_MILLION;
        address beneficiary = user1;
        vm.prank(OWNER);
        address vestingAddr = vestingManager.deployInvestorVesting(beneficiary, amount, startTimestamp);
        IInvestorVesting vesting = IInvestorVesting(vestingAddr);
        assertEq(oshiToken.balanceOf(vestingAddr), amount);
        assertEq(address(vesting.token()), address(oshiToken));
        assertEq(vesting.owner(), user1);
        assertEq(vesting.duration(), duration * 30 days);
        assertEq(vesting.start(), startTimestamp);
        assertEq(vesting.unreleased(), amount);
        assertEq(vesting.unreleasedAtM4(), amount / 10);
        assertEq(vesting.unreleasedAtM6(), amount - amount / 10);

        uint256 ReleaseAtM4 = vesting.unreleasedAtM4();
        uint256 ReleaseAtM6 = vesting.unreleasedAtM6();
        // 24 months vesting + 6 months cliff
        assertEq(vesting.end(), startTimestamp + 30 days * 30);
        // beneficiary transfer ownership to user2
        vm.prank(user1);
        vesting.transferOwnership(user2);
        assertEq(vesting.owner(), user2);
        // check release amount
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), 0);
        // 4 months later, release 10%
        vm.warp(block.timestamp + 30 days * 4);
        assertEq(vesting.released(), 0);
        assertEq(vesting.releasable(), ReleaseAtM4);
        // user2 release the 10% token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), ReleaseAtM4);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), ReleaseAtM4);
        // 7 months later
        vm.warp(block.timestamp + 30 days * 3);
        assertEq(vesting.releasable(), ReleaseAtM6 / duration);
        // user2 release the token
        vm.prank(user2);
        vesting.release();
        assertEq(vesting.released(), ReleaseAtM4 + ReleaseAtM6 / duration);
        assertEq(vesting.releasable(), 0);
        assertEq(oshiToken.balanceOf(user2), ReleaseAtM4 + ReleaseAtM6 / duration);
    }
}
