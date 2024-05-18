// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/helpers/SatoshiPeriphery.sol";

contract DeploySatoshiPeripheryScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    ISatoshiPeriphery satoshiPeriphery;
    IDebtToken debtToken = IDebtToken(0x1d015247bD90b92727A66Eae18608E34b8693487);
    IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0x0EE5326B901deEe0e47E620533d94a8055a7A97B);
    address constant WETH_ADDRESS = 0x4200000000000000000000000000000000000006;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        satoshiPeriphery = new SatoshiPeriphery(debtToken, borrowerOperationsProxy, IWETH(WETH_ADDRESS));

        console.log("SatoshiPeriphery: ", address(satoshiPeriphery));

        vm.stopBroadcast();
    }
}