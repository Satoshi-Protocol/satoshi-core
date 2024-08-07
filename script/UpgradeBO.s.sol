// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {BorrowerOperations} from "../src/core/BorrowerOperations.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UpgradeBOScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address borrowerOperationsProxyAddr = 0xaA1774e83127C741Fc7dA68550E6C17b3b2B5AcB;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        BorrowerOperations borrowerOperationsProxy = BorrowerOperations(borrowerOperationsProxyAddr);
        (IERC20 coll,) = borrowerOperationsProxy.troveManagersData(ITroveManager(0x0598Ef47508Ec11a503670Ac3B642AAE8EAEdEFA));

        IBorrowerOperations borrowerOperationsImpl = new BorrowerOperations();
        borrowerOperationsProxy.upgradeTo(address(borrowerOperationsImpl));

        (IERC20 coll_after,) = borrowerOperationsProxy.troveManagersData(ITroveManager(0x0598Ef47508Ec11a503670Ac3B642AAE8EAEdEFA));
        
        assert(address(coll) == address(coll_after));

        console.log("new BorrowerOperations Impl is deployed at", address(borrowerOperationsImpl));

        vm.stopBroadcast();
    }
}
