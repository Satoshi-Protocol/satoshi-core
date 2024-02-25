// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, BO_MIN_NET_DEBT,TestConfig} from "./TestConfig.sol";
import {Events} from "./utils/Events.sol";

contract UpgradteContractTest is Test, DeployBase, TestConfig, Events {

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    address user1;

    function setUp() public override {
        super.setUp();

        // testing user
        user1 = vm.addr(1);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );
    }

    function testUpgradeTo() public {
        vm.startPrank(OWNER);

        // deploy new borrower operations implementation
        IBorrowerOperations newBorrowerOperationsImpl = new BorrowerOperations();

        // upgrade to new borrower operations implementation
        BorrowerOperations borrowerOperationsProxy = BorrowerOperations(address(borrowerOperationsProxy));
        borrowerOperationsProxy.upgradeTo(address(newBorrowerOperationsImpl));
        bytes32 s = vm.load(address(borrowerOperationsProxy), BorrowerOperations(address(newBorrowerOperationsImpl)).proxiableUUID());
        // `0x000...address` << 96 -> `0xaddress000...000`
        s <<= 96;
        assertEq(s, bytes32(bytes20(address(newBorrowerOperationsImpl))));
        
        vm.stopPrank();
    }
}
