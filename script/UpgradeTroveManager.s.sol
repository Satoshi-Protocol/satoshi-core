// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/helpers/SatoshiPeriphery.sol";
import {TroveManager} from "../src/core/TroveManager.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeTroveManagerScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    IBeacon troveManagerBeacon = IBeacon(0xabF995EA0AE56b7C62E6bd9A61569395030ca678);

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        ITroveManager newTroveManagerImpl = new TroveManager();

        console.log("current TroveManager Impl is deployed at", address(troveManagerBeacon.implementation()));
        // upgrade to new trove manager implementation
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
        require(troveManagerBeacon.implementation() == address(newTroveManagerImpl), "implementation is not matched");

        console.log("new TroveManager Impl is deployed at", address(newTroveManagerImpl));

        vm.stopBroadcast();
    }
}
