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

contract DebtTokenTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    address user1;
    address user2;
    address user3;
    address user4;
    address vault;
    uint256 maxFeePercentage = 0.05e18; // 5%
    uint256 internal _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

    function setUp() public override {
        super.setUp();

        // 55% oshi allocation
        vault = vm.addr(1);

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

        // deploy debt token tester
        _deployOSHITokenTester(vault);

        // mint some tokens
        oshiTokenTester.unprotectedMint(user1, 150);
        oshiTokenTester.unprotectedMint(user2, 100);
        oshiTokenTester.unprotectedMint(user3, 50);
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

    function testGetsBalanceOfUser() public {
        assertEq(oshiTokenTester.balanceOf(user1), 150);
        assertEq(oshiTokenTester.balanceOf(user2), 100);
        assertEq(oshiTokenTester.balanceOf(user3), 50);
        assertEq(oshiTokenTester.balanceOf(vault), _1_MILLION * 55);
        assertEq(oshiToken.balanceOf(VAULT), _1_MILLION * 55);
        assertEq(oshiToken.totalSupply(), _1_MILLION * 100);
        address communityIssuanceAddress = oshiTokenTester.communityIssuanceAddress();
        assertEq(oshiTokenTester.balanceOf(communityIssuanceAddress), _1_MILLION * 45);
    }

    function testGetsTotalSupply() public {
        assertEq(oshiTokenTester.totalSupply(), 300 + _1_MILLION * 100);
    }

    function testTokenName() public {
        assertEq(oshiTokenTester.name(), "OSHI");
    }

    function testSymbol() public {
        assertEq(oshiTokenTester.symbol(), "OSHI");
    }

    function testDecimals() public {
        assertEq(oshiTokenTester.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        oshiTokenTester.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = oshiTokenTester.allowance(user1, user2);
        uint256 allowance2 = oshiTokenTester.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        oshiTokenTester.transfer(user2, 50);
        assertEq(oshiTokenTester.balanceOf(user1), 100);
        assertEq(oshiTokenTester.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(oshiTokenTester.allowance(user1, user2), 0);

        vm.prank(user1);
        oshiTokenTester.approve(user2, 50);
        assertEq(oshiTokenTester.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(oshiTokenTester.transferFrom(user1, user3, 50));
        assertEq(oshiTokenTester.balanceOf(user3), 100);
        assertEq(oshiTokenTester.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        oshiTokenTester.transferFrom(user1, user3, 50);
    }

    function testFailApproveToZeroAddress() public {
        oshiTokenTester.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        vm.prank(user1);
        oshiTokenTester.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        vm.prank(user1);
        oshiTokenTester.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        vm.prank(user1);
        oshiTokenTester.approve(address(this), 10);
        oshiTokenTester.transferFrom(user1, user2, 20);
    }

    function testPermit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        oshiTokenTester.unprotectedMint(owner, 100);

        uint256 nonce = oshiTokenTester.nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 100;

        bytes32 digest = oshiTokenTester.getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        oshiTokenTester.permit(owner, user2, amount, deadline, v, r, s);

        assertEq(oshiTokenTester.allowance(owner, user2), amount);
    }
}
