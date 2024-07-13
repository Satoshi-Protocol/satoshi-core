// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "./utils/DeployBase.t.sol";
import {HintLib} from "./utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, VAULT, FEE_RECEIVER} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {OSHIToken} from "../src/OSHI/OSHIToken.sol";

contract OSHITokenTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    OSHIToken oshiToken;
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

        oshiToken = OSHIToken(address(oshiTokenProxy));

        vm.startPrank(OWNER);
        // mint some tokens
        oshiToken.mint(user1, 150);
        oshiToken.mint(user2, 100);
        oshiToken.mint(user3, 50);

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
                oshiToken.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

    function testGetsBalanceOfUser() public {
        assertEq(oshiToken.balanceOf(user1), 150);
        assertEq(oshiToken.balanceOf(user2), 100);
        assertEq(oshiToken.balanceOf(user3), 50);
    }

    function testGetsTotalSupply() public {
        assertEq(oshiToken.totalSupply(), 300);
    }

    function testTokenName() public {
        assertEq(oshiToken.name(), "OSHI");
    }

    function testSymbol() public {
        assertEq(oshiToken.symbol(), "OSHI");
    }

    function testDecimals() public {
        assertEq(oshiToken.decimals(), 18);
    }

    function testAllowance() public {
        vm.startPrank(user1);
        oshiToken.approve(user2, 100);
        vm.stopPrank();

        uint256 allowance1 = oshiToken.allowance(user1, user2);
        uint256 allowance2 = oshiToken.allowance(user1, user3);

        assertEq(allowance1, 100);
        assertEq(allowance2, 0);
    }

    function testTransfer() public {
        vm.prank(user1);
        oshiToken.transfer(user2, 50);
        assertEq(oshiToken.balanceOf(user1), 100);
        assertEq(oshiToken.balanceOf(user2), 150);
    }

    function testTransferFrom() public {
        assertEq(oshiToken.allowance(user1, user2), 0);

        vm.prank(user1);
        oshiToken.approve(user2, 50);
        assertEq(oshiToken.allowance(user1, user2), 50);

        vm.prank(user2);
        assertTrue(oshiToken.transferFrom(user1, user3, 50));
        assertEq(oshiToken.balanceOf(user3), 100);
        assertEq(oshiToken.balanceOf(user1), 150 - 50);

        vm.expectRevert();
        oshiToken.transferFrom(user1, user3, 50);
    }

    function testFailApproveToZeroAddress() public {
        oshiToken.approve(address(0), 1e18);
    }

    function testFailTransferToZeroAddress() public {
        vm.prank(user1);
        oshiToken.transfer(address(0), 10);
    }

    function testFailTransferInsufficientBalance() public {
        vm.prank(user1);
        oshiToken.transfer(user2, 3e18);
    }

    function testFailTransferFromInsufficientApprove() public {
        vm.prank(user1);
        oshiToken.approve(address(this), 10);
        oshiToken.transferFrom(user1, user2, 20);
    }

    function testPermit() public {
        uint256 ownerPrivateKey = 0xA11CE;
        address owner = vm.addr(ownerPrivateKey);
        vm.prank(OWNER);
        oshiToken.mint(owner, 100);

        uint256 nonce = oshiToken.nonces(owner);
        uint256 deadline = block.timestamp + 1000;
        uint256 amount = 100;

        bytes32 digest = getDigest(owner, user2, amount, nonce, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, digest);

        oshiToken.permit(owner, user2, amount, deadline, v, r, s);

        assertEq(oshiToken.allowance(owner, user2), amount);
    }

    function testBurnToken() public {
        vm.startPrank(OWNER);
        oshiToken.mint(user1, 150);
        oshiToken.burn(user1, 150);
        assertEq(oshiToken.balanceOf(user1), 150);
        assertEq(oshiToken.totalSupply(), 300);
        vm.stopPrank();
    }
}
