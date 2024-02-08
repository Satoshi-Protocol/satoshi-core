// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {DeployBase} from "./DeployBase.t.sol";
import {DEPLOYER, OWNER, TestConfig} from "./TestConfig.sol";

contract BorrowerOperationTest is Test, DeployBase, TestConfig {
    function setUp() public override {
        super.setUp();

        _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, roundData, COLLATERAL, deploymentParams
        );
    }

    function testBO() public {}
}
