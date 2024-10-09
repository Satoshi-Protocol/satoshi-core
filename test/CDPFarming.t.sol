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
    _1_MILLION,
    INTEREST_RATE_IN_BPS
} from "./TestConfig.sol";
import {TroveBase} from "./utils/TroveBase.t.sol";
import {Events} from "./utils/Events.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS, REWARD_MANAGER_GAIN, REWARD_MANAGER_PRECISION} from "./TestConfig.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {SimpleVault} from "../src/vault/SimpleVault.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {IVaultManager} from "../src/interfaces/vault/IVaultManager.sol";
import {INYMVault} from "../src/interfaces/vault/INYMVault.sol";

contract CDPFarmingTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    SimpleVault simpleVaultProxy;
    address user1;
    address user2;
    address user3;

    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        simpleVaultProxy = SimpleVault(_deploySimpleVault(address(collateralMock)));
        INYMVault[] memory vaults = new INYMVault[](1);
        vaults[0] = INYMVault(address(simpleVaultProxy));
        _deployVaultManager(troveManagerBeaconProxy);
        _setCDPFarming(troveManagerBeaconProxy);
        _setVaultManagerWL(vaults);
        vm.prank(OWNER);
        simpleVaultProxy.setWhitelist(address(vaultManagerProxy), true);
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

    function _updateRoundData(RoundData memory data) internal {
        TroveBase.updateRoundData(oracleMockAddr, DEPLOYER, data);
    }

    function test_getTotalActiveCollateral() public {
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 0);
        _openTrove(OWNER, 1e18, 1000e18);
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 1e18);
    }

    function test_transerCollToPrivilegedVault() public {
        // open trove
        _openTrove(OWNER, 1e18, 1000e18);

        vm.startPrank(OWNER);
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), 0.7e18);

        assertEq(collateralMock.balanceOf(address(troveManagerBeaconProxy)), 0.3e18);

        vm.expectRevert("TroveManager: Exceed the collateral transfer limit");
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), 1);

        // transfer funds back
        vaultManagerProxy.transferCollToTroveManager(0.7e18);

        assert(troveManagerBeaconProxy.getTotalActiveCollateral() == 1e18);
        assert(collateralMock.balanceOf(address(troveManagerBeaconProxy)) == 1e18);
        vm.stopPrank();
    }

    function test_refillCollToTroveManager_CloseTrove() public {
        uint256 collAmount = 1e18;
        uint256 debtAmount = 1000e18;
        uint256 farmingAmount = 0.7e18;
        // open trove
        _openTrove(OWNER, collAmount, debtAmount);
        deal(address(debtTokenProxy), OWNER, 2000e18);

        vm.startPrank(OWNER);
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(collateralMock.balanceOf(address(troveManagerBeaconProxy)), collAmount - farmingAmount);
        assertEq(collateralMock.balanceOf(address(vaultManagerProxy)), farmingAmount);
        vm.stopPrank();

        // close trove, it should trigger the refill
        _closeTrove(OWNER);

        // check the trove status
        assertEq(troveManagerBeaconProxy.getTotalActiveCollateral(), 0);
        assertFalse(sortedTrovesBeaconProxy.contains(OWNER));
        assertEq(collateralMock.balanceOf(OWNER), collAmount);
    }

    function test_refillCollToTroveManager_WithdrawColl() public {
        uint256 collAmount = 1e18;
        uint256 debtAmount = 1000e18;
        uint256 farmingAmount = 0.7e18;
        // open trove
        _openTrove(OWNER, collAmount, debtAmount);
        deal(address(debtTokenProxy), OWNER, 2000e18);

        vm.startPrank(OWNER);
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(collateralMock.balanceOf(address(troveManagerBeaconProxy)), collAmount - farmingAmount);
        assertEq(collateralMock.balanceOf(address(vaultManagerProxy)), farmingAmount);
        vm.stopPrank();

        // withdraw collateral
        (uint256 collBefore, uint256 debtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(OWNER);

        uint256 withdrawAmount = 0.1e18;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            collBefore - withdrawAmount,
            debtBefore,
            0.05e18
        );

        vm.prank(OWNER);
        borrowerOperationsProxy.withdrawColl(troveManagerBeaconProxy, OWNER, withdrawAmount, upperHint, lowerHint);

        // check the trove status
        assertEq(collateralMock.balanceOf(OWNER), withdrawAmount);
        assertEq(
            collateralMock.balanceOf(address(troveManagerBeaconProxy)),
            troveManagerBeaconProxy.getTotalActiveCollateral() * troveManagerBeaconProxy.refillPercentage()
                / troveManagerBeaconProxy.FARMING_PRECISION()
        );
    }

    function test_remainCollIsEnough() public {
        uint256 collAmount = 1e18;
        uint256 debtAmount = 1000e18;
        uint256 farmingAmount = 0.1e18;
        // open trove
        _openTrove(OWNER, collAmount, debtAmount);
        deal(address(debtTokenProxy), OWNER, 2000e18);

        vm.startPrank(OWNER);
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(collateralMock.balanceOf(address(troveManagerBeaconProxy)), collAmount - farmingAmount);
        assertEq(collateralMock.balanceOf(address(vaultManagerProxy)), farmingAmount);
        vm.stopPrank();

        // withdraw collateral, the remain collateral is enough, so no refill
        (uint256 collBefore, uint256 debtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(OWNER);

        uint256 withdrawAmount = 0.1e18;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            collBefore - withdrawAmount,
            debtBefore,
            0.05e18
        );

        vm.prank(OWNER);
        borrowerOperationsProxy.withdrawColl(troveManagerBeaconProxy, OWNER, withdrawAmount, upperHint, lowerHint);

        // check the trove status
        assertEq(collateralMock.balanceOf(OWNER), withdrawAmount);
        assertEq(
            collateralMock.balanceOf(address(troveManagerBeaconProxy)),
            troveManagerBeaconProxy.getTotalActiveCollateral() - farmingAmount
        );
    }

    function test_refillCollToTroveManager_SimpleVault() public {
        uint256 collAmount = 1e18;
        uint256 debtAmount = 1000e18;
        uint256 farmingAmount = 0.7e18;
        // open trove
        _openTrove(OWNER, collAmount, debtAmount);
        deal(address(debtTokenProxy), OWNER, 2000e18);

        vm.startPrank(OWNER);
        troveManagerBeaconProxy.transerCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(collateralMock.balanceOf(address(troveManagerBeaconProxy)), collAmount - farmingAmount);
        assertEq(collateralMock.balanceOf(address(vaultManagerProxy)), farmingAmount);

        vaultManagerProxy.executeStrategy(address(simpleVaultProxy), farmingAmount);
        vm.stopPrank();

        // withdraw collateral
        (uint256 collBefore, uint256 debtBefore) = troveManagerBeaconProxy.getTroveCollAndDebt(OWNER);

        uint256 withdrawAmount = 0.1e18;
        // calc hint
        (address upperHint, address lowerHint) = HintLib.getHint(
            hintHelpers,
            sortedTrovesBeaconProxy,
            troveManagerBeaconProxy,
            collBefore - withdrawAmount,
            debtBefore,
            0.05e18
        );

        vm.prank(OWNER);
        borrowerOperationsProxy.withdrawColl(troveManagerBeaconProxy, OWNER, withdrawAmount, upperHint, lowerHint);

        // check the trove status
        assertEq(collateralMock.balanceOf(OWNER), withdrawAmount);
        assertEq(
            collateralMock.balanceOf(address(troveManagerBeaconProxy)),
            troveManagerBeaconProxy.getTotalActiveCollateral() * troveManagerBeaconProxy.refillPercentage()
                / troveManagerBeaconProxy.FARMING_PRECISION()
        );
    }
}
