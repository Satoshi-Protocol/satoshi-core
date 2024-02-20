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
import {FlashloanTester} from "./FlashloanTester.sol";

contract DebtTokenTest is Test, DeployBase, TroveBase, TestConfig, Events {
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

        // deploy debt token tester
        _deployDebtTokenTester();

        // mint some tokens
        debtTokenTester.unprotectedMint(user1, 150);
        debtTokenTester.unprotectedMint(user2, 100);
        debtTokenTester.unprotectedMint(user3, 50);
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
        assertEq(debtTokenTester.balanceOf(user1), 150);
        assertEq(debtTokenTester.balanceOf(user2), 100);
        assertEq(debtTokenTester.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(debtTokenTester.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(debtTokenTester.name(), "TEST_TOKEN_NAME");
    }

    function testSymbol() public {
        assertEq(debtTokenTester.symbol(), "TEST_TOKEN_SYMBOL");
    }

    function testDecimals() public {
        assertEq(debtTokenTester.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        debtTokenTester.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = debtTokenTester.allowance(user1, user2);
        uint256 allowance2 = debtTokenTester.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        debtTokenTester.transfer(user2, 50);
        assertEq(debtTokenTester.balanceOf(user1), 100);
        assertEq(debtTokenTester.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(debtTokenTester.allowance(user1, user2), 0);

        vm.prank(user1);
        debtTokenTester.approve(user2, 50);
        assertEq(debtTokenTester.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(debtTokenTester.transferFrom(user1, user3, 50));
        assertEq(debtTokenTester.balanceOf(user3), 100);
        assertEq(debtTokenTester.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        debtTokenTester.transferFrom(user1, user3, 50);
    }

    function testMint() public {
        vm.prank(address(debtTokenTester.borrowerOperations()));
        debtTokenTester.mint(user1, 50);
        assertEq(debtTokenTester.balanceOf(user1), 200);
    }

    function testFailMintToZero() public {
        vm.prank(address(debtTokenTester.borrowerOperations()));
        debtTokenTester.mint(address(0), 1e18);
    }

    function testFailBurnFromZero() public {
        vm.prank(address(debtTokenTester.borrowerOperations()));
        debtTokenTester.burn(address(0), 1e18);
    }

    function testFailBurnInsufficientBalance() public {
        vm.prank(user1);
        debtTokenTester.burn(user1, 3e18);
    }

    function testFailApproveToZeroAddress() public {
        debtTokenTester.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        testMint();
        vm.prank(user1);
        debtTokenTester.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        testMint();
        vm.prank(user1);
        debtTokenTester.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        testMint();
        vm.prank(user1);
        debtTokenTester.approve(address(this), 10);
        debtTokenTester.transferFrom(user1, user2, 20);
    }

    function testPermit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        debtTokenTester.unprotectedMint(owner, 100);

        uint256 nonce = debtTokenTester.nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 100;

        bytes32 digest = debtTokenTester.getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        debtTokenTester.permit(owner, user2, amount, deadline, v, r, s);

        assertEq(debtTokenTester.allowance(owner, user2), amount);
    }

    function testFlashloan() public {
        uint256 totalSupplyBefore = debtTokenTester.totalSupply();
        uint256 amount = 10000e18;
        FlashloanTester flashloanTester = new FlashloanTester(debtTokenTester);
        // mint fee to tester
        debtTokenTester.unprotectedMint(address(flashloanTester), 9e18);
        flashloanTester.flashBorrow(address(debtTokenTester), amount);
        assertEq(debtTokenTester.allowance(address(this), address(flashloanTester)), 0);
        assertEq(debtTokenTester.balanceOf(satoshiCore.feeReceiver()), 9e18);
        assertEq(debtTokenTester.totalSupply() - 9e18, totalSupplyBefore);
    }
}
