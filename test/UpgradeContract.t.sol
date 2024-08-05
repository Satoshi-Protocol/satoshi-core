// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {DeployBase} from "./utils/DeployBase.t.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, BO_MIN_NET_DEBT, TestConfig} from "./TestConfig.sol";
import {Events} from "./utils/Events.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";

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
        bytes32 s = vm.load(
            address(borrowerOperationsProxy), BorrowerOperations(address(newBorrowerOperationsImpl)).proxiableUUID()
        );
        // `0x000...address` << 96 -> `0xaddress000...000`
        s <<= 96;
        assertEq(s, bytes32(bytes20(address(newBorrowerOperationsImpl))));

        vm.stopPrank();
    }

    function testUpgradeTroveManager() public {
        vm.startPrank(DEPLOYER);

        // deploy new trove manager implementation
        ITroveManager newTroveManagerImpl = new TroveManager();

        // upgrade to new trove manager implementation
        UpgradeableBeacon(address(troveManagerBeacon)).upgradeTo(address(newTroveManagerImpl));
        assert(UpgradeableBeacon(address(troveManagerBeacon)).implementation() == address(newTroveManagerImpl));

        // check the max interest rate
        assertEq(troveManagerBeaconProxy.MAX_INTEREST_RATE_IN_BPS(), 10000);

        vm.stopPrank();
    }

    function testUpgradStabilityPool() public {
        vm.startPrank(OWNER);

        // deploy new stability pool implementation
        IStabilityPool newStabilityPoolImpl = new StabilityPool();

        // upgrade to new stability pool implementation
        StabilityPool stabilityPoolProxy = StabilityPool(address(stabilityPoolProxy));
        stabilityPoolProxy.upgradeTo(address(newStabilityPoolImpl));
        bytes32 s =
            vm.load(address(stabilityPoolProxy), BorrowerOperations(address(newStabilityPoolImpl)).proxiableUUID());
        // `0x000...address` << 96 -> `0xaddress000...000`
        s <<= 96;
        assertEq(s, bytes32(bytes20(address(newStabilityPoolImpl))));

        vm.stopPrank();
    }
}
