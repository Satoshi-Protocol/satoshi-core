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
import {TroveManagerGetters, Collateral} from "../src/helpers/TroveManagerGetters.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";

contract TroveManagerGettersTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    TroveManagerGetters troveManagerGetters;

    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        troveManagerGetters = new TroveManagerGetters(factoryProxy);
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

    function test_getAllCollateralsAndTroveManagers() public {
        Collateral[] memory coll = troveManagerGetters.getAllCollateralsAndTroveManagers();
        assertEq(coll[0].troveManagers[0], address(troveManagerBeaconProxy));
        assertEq(coll[0].collateral, address(collateralMock));
    }

    function test_getActiveTroveManagersForAccount() public {
        _openTrove(OWNER, 1e18, 1000e18);
        (ITroveManager[] memory troveManagers, uint256 tmCount) = troveManagerGetters.getActiveTroveManagersForAccount(OWNER);
        assertEq(address(troveManagers[0]), address(troveManagerBeaconProxy));
        assertEq(tmCount, 1);
    }
}
