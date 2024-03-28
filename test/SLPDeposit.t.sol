// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, VAULT} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {ISatoshiLPToken} from "../src/interfaces/core/ISatoshiLPToken.sol";
import {MockUniswapV2ERC20} from "./MockUniswapV2ERC20.sol";

contract SLPDepositTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    uint256 maxFeePercentage = 0.05e18; // 5%
    uint256 internal _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
    MockUniswapV2ERC20 lpToken;
    ISatoshiLPToken slpToken;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(2);
        user2 = vm.addr(3);
        user3 = vm.addr(4);
        user4 = vm.addr(5);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        // deploy mock uni-v2 token
        lpToken = MockUniswapV2ERC20(_deployMockUniV2Token());
        // deploy debt token tester
        slpToken = ISatoshiLPToken(_deploySLPToken(IERC20(address(lpToken))));

        vm.startPrank(OWNER);
        // set allocation in community issuance
        address[] memory receipient = new address[](1);
        receipient[0] = address(slpToken);
        uint256[] memory amount = new uint256[](1);
        amount[0] = 15e24;
        communityIssuance.setAllocated(receipient, amount);
        // set reward rate
        slpToken.setRewardRate(95129375951293760); // 15e24 / (5 * 31536000)
        assertEq(slpToken.rewardRate(), 95129375951293760);
        vm.stopPrank();
    }

    function test_SLPDepositAndWithdraw() public {
        lpToken.mint(user1, 100);
        assertEq(lpToken.balanceOf(user1), 100);
        vm.startPrank(user1);
        lpToken.approve(address(slpToken), 100);
        slpToken.deposit(100);
        assertEq(lpToken.balanceOf(user1), 0);
        assertEq(slpToken.balanceOf(user1), 100);
        slpToken.withdraw(50);
        assertEq(lpToken.balanceOf(user1), 50);
        assertEq(slpToken.balanceOf(user1), 50);
        vm.stopPrank();
    }

    function test_claimRewardFromSLP() public {
        lpToken.mint(user1, 100);
        vm.startPrank(user1);
        lpToken.approve(address(slpToken), 100);
        slpToken.deposit(100);
        assertEq(slpToken.claimableReward(user1), 0);

        vm.warp(block.timestamp + 10000);
        uint256 expectedOSHIReward = 10000 * slpToken.rewardRate();
        assertEq(slpToken.claimableReward(user1), expectedOSHIReward);
        slpToken.claimReward();
        assertEq(slpToken.claimableReward(user1), 0);
        assertEq(oshiToken.balanceOf(user1), expectedOSHIReward);
        vm.stopPrank();
    }

    function test_claimRewardFromSLPAfter6Y() public {
        lpToken.mint(user1, 100);
        vm.startPrank(user1);
        lpToken.approve(address(slpToken), 100);
        slpToken.deposit(100);
        assertEq(slpToken.claimableReward(user1), 0);

        vm.warp(block.timestamp + 365 days * 6);
        uint256 expectedOSHIReward = 15e24;
        assertEq(slpToken.claimableReward(user1), expectedOSHIReward);
        slpToken.claimReward();
        assertEq(slpToken.claimableReward(user1), 0);
        assertEq(oshiToken.balanceOf(user1), expectedOSHIReward);
        vm.stopPrank();
    }

    function test_transferSLP() public {
        lpToken.mint(user1, 100);
        vm.startPrank(user1);
        lpToken.approve(address(slpToken), 100);
        slpToken.deposit(100);
        assertEq(slpToken.balanceOf(user1), 100);

        vm.warp(block.timestamp + 10000);
        uint256 expectedOSHIReward = 10000 * slpToken.rewardRate();
        slpToken.transfer(user2, 50);
        assertEq(slpToken.balanceOf(user1), 50);
        assertEq(slpToken.balanceOf(user2), 50);
        assertEq(slpToken.claimableReward(user1), expectedOSHIReward);
        assertEq(slpToken.claimableReward(user2), 0);
        slpToken.claimReward();
        assertEq(oshiToken.balanceOf(user1), expectedOSHIReward);
        vm.stopPrank();

        vm.warp(block.timestamp + 10000);
        assertEq(slpToken.claimableReward(user1), slpToken.claimableReward(user2));
        expectedOSHIReward = 10000 * slpToken.rewardRate() / 2;
        assertEq(slpToken.claimableReward(user1), expectedOSHIReward);
        assertEq(slpToken.claimableReward(user2), expectedOSHIReward);
    }

    function test_withdrawMoreThanBalance() public {
        lpToken.mint(user1, 100);
        vm.startPrank(user1);
        lpToken.approve(address(slpToken), 100);
        slpToken.deposit(100);
        assertEq(slpToken.balanceOf(user1), 100);
        vm.expectRevert("SatoshiLPToken: insufficient balance");
        slpToken.withdraw(101);
        vm.stopPrank();
    }

    function test_withdrawMoreThanBalance1() public {
        vm.startPrank(user1);
        vm.expectRevert("SatoshiLPToken: insufficient balance");
        slpToken.withdraw(1);
        vm.stopPrank();
    }
}
