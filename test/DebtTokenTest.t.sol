// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
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
import {DebtToken} from "../src/core/DebtToken.sol";

contract DebtTokenTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    DebtToken debtToken;
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

        debtToken = DebtToken(address(debtTokenProxy));
        
        vm.startPrank(address(debtToken.borrowerOperations()));
        debtToken.mint(user1, 150);
        debtToken.mint(user2, 100);
        debtToken.mint(user3, 50);
        vm.stopPrank();
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

    function getDigest(address owner, address spender, uint256 amount, uint256 nonce, uint256 deadline)
        public
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                uint16(0x1901),
                debtToken.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

    function testGetsBalanceOfUser() public {
        assertEq(debtToken.balanceOf(user1), 150);
        assertEq(debtToken.balanceOf(user2), 100);
        assertEq(debtToken.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(debtToken.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(debtToken.name(), "TEST_TOKEN_NAME");
    }

    function testSymbol() public {
        assertEq(debtToken.symbol(), "TEST_TOKEN_SYMBOL");
    }

    function testDecimals() public {
        assertEq(debtToken.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        debtToken.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = debtToken.allowance(user1, user2);
        uint256 allowance2 = debtToken.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        debtToken.transfer(user2, 50);
        assertEq(debtToken.balanceOf(user1), 100);
        assertEq(debtToken.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(debtToken.allowance(user1, user2), 0);

        vm.prank(user1);
        debtToken.approve(user2, 50);
        assertEq(debtToken.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(debtToken.transferFrom(user1, user3, 50));
        assertEq(debtToken.balanceOf(user3), 100);
        assertEq(debtToken.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        debtToken.transferFrom(user1, user3, 50);
    }

    function testMint() public {
        vm.prank(address(debtToken.borrowerOperations()));
        debtToken.mint(user1, 50);
        assertEq(debtToken.balanceOf(user1), 200);
    }

    function testFailMintToZero() public {
        vm.prank(address(debtToken.borrowerOperations()));
        debtToken.mint(address(0), 1e18);
    }

    function testFailBurnFromZero() public {
        vm.prank(address(debtToken.borrowerOperations()));
        debtToken.burn(address(0), 1e18);
    }

    function testFailBurnInsufficientBalance() public {
        vm.prank(user1);
        debtToken.burn(user1, 3e18);
    }

    function testFailApproveToZeroAddress() public {
        debtToken.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        testMint();
        vm.prank(user1);
        debtToken.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        testMint();
        vm.prank(user1);
        debtToken.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        testMint();
        vm.prank(user1);
        debtToken.approve(address(this), 10);
        debtToken.transferFrom(user1, user2, 20);
    }

    function testPermit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        vm.prank(address(debtToken.borrowerOperations()));
        debtToken.mint(owner, 1000);

        uint256 nonce = debtToken.nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 1000;

        bytes32 digest = getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        debtToken.permit(owner, user2, amount, deadline, v, r, s);

        assertEq(debtToken.allowance(owner, user2), amount);
    }

    function testFlashloan() public {
        uint256 totalSupplyBefore = debtToken.totalSupply();
        uint256 amount = 10000e18;
        FlashloanTester flashloanTester = new FlashloanTester(debtToken);
        // mint fee to tester
        vm.prank(address(debtToken.borrowerOperations()));
        debtToken.mint(address(flashloanTester), 9e18);
        flashloanTester.flashBorrow(address(debtToken), amount);
        assertEq(debtToken.allowance(address(this), address(flashloanTester)), 0);
        assertEq(debtToken.balanceOf(satoshiCore.rewardManager()), 9e18);
        assertEq(debtToken.totalSupply() - 9e18, totalSupplyBefore);
    }
}
