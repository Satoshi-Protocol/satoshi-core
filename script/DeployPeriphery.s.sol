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
    IDebtToken debtToken = IDebtToken(0xc39134ADEC50C8117af93bD311C602a55a581eDc);
    IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0xB18EAb008C7D71c0419a389085FA9e775d7d48A2);
    address constant WETH_ADDRESS = 0x2DcA0825F0d5E900c1522a9A2362237BbaAecbb4;

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
