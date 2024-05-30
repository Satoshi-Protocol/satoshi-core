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
import {SatoshiMath} from "../src/dependencies/SatoshiMath.sol";
import {TroveHelper} from "../src/helpers/TroveHelper.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";

contract TroveHelperTest is Test, DeployBase, TroveBase, TestConfig, Events {
    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    TroveHelper troveHelper;

    uint256 maxFeePercentage = 0.05e18; // 5%

    function setUp() public override {
        super.setUp();

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        troveHelper = new TroveHelper();
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

    function test_getNicrByTime() public {
        _openTrove(OWNER, 1e18, 1000e18);
        uint256 time = block.timestamp;
        uint256 nicr = troveHelper.getNicrByTime(troveManagerBeaconProxy, OWNER, time);
        (uint256 debt, uint256 coll,,,,) = troveManagerBeaconProxy.troves(OWNER);
        uint256 expectnicr = SatoshiMath._computeNominalCR(coll, debt);
        assertEq(nicr, expectnicr);
    }

    function test_getNicrListByTime() public {
        _openTrove(OWNER, 1e18, 1000e18);
        uint256 time = block.timestamp;
        uint256 nicr = troveHelper.getNicrByTime(troveManagerBeaconProxy, OWNER, time);
        address[] memory borrowers = new address[](1);
        borrowers[0] = OWNER;
        uint256[] memory nicrList = troveHelper.getNicrListByTime(troveManagerBeaconProxy, borrowers, time);
        assertEq(nicrList[0], nicr);
    }

    function test_calculateInterestIndexByTime() public {
        _openTrove(OWNER, 1e18, 1000e18);
        uint256 time = block.timestamp + 1 days;
        (uint256 currentInterestIndex, uint256 interestFactor) =
            troveHelper.calculateInterestIndexByTime(troveManagerBeaconProxy, time);
        assertEq(currentInterestIndex, 1000136986301369863013680000);
        assertEq(interestFactor, 136986301369863013680000);
    }

    function test_getNode() public {
        _openTrove(OWNER, 1e18, 1000e18);
        _openTrove(DEPLOYER, 1e18, 1000e18);
        (bool exist, address nextId, address prevId) = troveHelper.getNode(address(sortedTrovesBeaconProxy), OWNER);
        assertTrue(exist);
        assertEq(nextId, address(0));
        assertEq(prevId, DEPLOYER);
    }
}
