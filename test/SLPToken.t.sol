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

contract SLPTokenTest is Test, DeployBase, TroveBase, TestConfig, Events {
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
        address lpToken = _deployMockUniV2Token();
        // deploy debt token tester
        _deploySLPTokenTester(IERC20(lpToken));

        // mint some tokens
        slpTokenTester.unprotectedMint(user1, 150);
        slpTokenTester.unprotectedMint(user2, 100);
        slpTokenTester.unprotectedMint(user3, 50);
    }

    function testGetsBalanceOfUser() public {
        assertEq(slpTokenTester.balanceOf(user1), 150);
        assertEq(slpTokenTester.balanceOf(user2), 100);
        assertEq(slpTokenTester.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(slpTokenTester.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(slpTokenTester.name(), "SLP");
    }

    function testSymbol() public {
        assertEq(slpTokenTester.symbol(), "SLP");
    }

    function testDecimals() public {
        assertEq(slpTokenTester.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        slpTokenTester.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = slpTokenTester.allowance(user1, user2);
        uint256 allowance2 = slpTokenTester.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        slpTokenTester.transfer(user2, 50);
        assertEq(slpTokenTester.balanceOf(user1), 100);
        assertEq(slpTokenTester.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(slpTokenTester.allowance(user1, user2), 0);

        vm.prank(user1);
        slpTokenTester.approve(user2, 50);
        assertEq(slpTokenTester.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(slpTokenTester.transferFrom(user1, user3, 50));
        assertEq(slpTokenTester.balanceOf(user3), 100);
        assertEq(slpTokenTester.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        slpTokenTester.transferFrom(user1, user3, 50);
    }

    function testFailApproveToZeroAddress() public {
        slpTokenTester.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        vm.prank(user1);
        slpTokenTester.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        vm.prank(user1);
        slpTokenTester.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        vm.prank(user1);
        slpTokenTester.approve(address(this), 10);
        slpTokenTester.transferFrom(user1, user2, 20);
    }
}
