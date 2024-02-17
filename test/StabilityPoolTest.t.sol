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

contract StabilityPoolTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
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
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, roundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));
    }

    // utils
    function _openTrove(
        address caller,
        uint256 collateralAmt,
        uint256 debtAmt 
    ) internal {
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

    function _provideToSP(
        address caller,
        uint256 amount
    ) internal {
        TroveBase.provideToSP(stabilityPoolProxy, caller, amount);
    }

    function _withdrawFromSP(
        address caller,
        uint256 amount
    ) internal {
        TroveBase.withdrawFromSP(stabilityPoolProxy, caller, amount);
    }
    
    // deposit to SP and check the stake amount in SP
    function testProvideToSP() public {
        // open trove
        _openTrove(user1, 1e18, 10000e18);
        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtBefore, 0);
        
        // deposit to SP
        _provideToSP(user1, 200e18);
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtAfter, 200e18);
    }

    // withdraw from SP and check the stake amount in SP
    function testWithdrawFromSPFull() public {
        // open trove
        _openTrove(user1, 1e18, 10000e18);
        
        uint256 stabilityPoolDebtBefore = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtBefore, 0);
        
        // deposit to SP
        _provideToSP(user1, 200e18);

        vm.warp(block.timestamp + 1);

        // withdraw from SP
        _withdrawFromSP(user1, 200e18); //@todo panic: division or modulo by zero (0x12)
        uint256 stabilityPoolDebtAfter = stabilityPoolProxy.getTotalDebtTokenDeposits();
        assertEq(stabilityPoolDebtAfter, 0);
    }

    // function testLiquidate() public {
    //     _openTrove(user1, 100e18, 185000e18);
    //     _provideToSP(user1, 185000e18);
    // }

    /*
    - BO: global state and personal state calculation, operations in normal mode and recovery mode
    - TM: Trove operations, Redeem, remaining claimed Coll after redeem, Redistribution
    - Liquidation: liquidate, liquidateTroves, batchLiquidateTroves, reward distribution
    - Price Aggregator: Add timestamp check
    - DebtToken Operation: Flashloan, permit, erc20 functions…
    - Stability Pool: ProvideToSP, WithdrawToSP
    - Fee calculation and claim: One time borrowing fee, interest rate…
    - Router review
    - Contract upgrade test
    */
    
}