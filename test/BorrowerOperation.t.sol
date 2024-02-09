// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {MultiCollateralHintHelpers} from "../src/helpers/MultiCollateralHintHelpers.sol";
import {PrismaMath} from "../src/dependencies/PrismaMath.sol";
import {DeployBase} from "./DeployBase.t.sol";
import {HintHelpers} from "./HintHelpers.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig} from "./TestConfig.sol";

contract BorrowerOperationTest is Test, DeployBase, HintHelpers, TestConfig {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    address user1;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        
        // deploy all contracts
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, roundData, collateralMock, deploymentParams
        );

        // deploy helper contract
        _deployHintHelpers(DEPLOYER);

    }

    function testOpenTrove() public {
        vm.startPrank(user1);
        deal(address(collateralMock), user1, 10e18);
        collateralMock.approve(address(borrowerOperationsProxy), 1e18);

        uint256 collateralAmt = 1e18;
        uint256 debtAmt = 10000e18;
        uint256 maxFeePercentage = 0.05e18; // 5%
        (address upperHint, address lowerHint) =
            _getHint(hintHelpers, sortedTrovesBeaconProxy, troveManagerBeaconProxy, collateralAmt, debtAmt, GAS_COMPENSATION);

        borrowerOperationsProxy.openTrove(
            troveManagerBeaconProxy, user1, maxFeePercentage, collateralAmt, debtAmt, upperHint, lowerHint
        );

        vm.stopPrank();
    }
}
