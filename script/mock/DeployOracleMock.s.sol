// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {OracleMock} from "../../src/mocks/OracleMock.sol";
import {AggregatorV3Interface} from "../../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

uint8 constant DECIMALS = 8;
uint256 constant VERSION = 1;

contract DeployOracleMockScript is Script {
    AggregatorV3Interface internal oracleMock;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        oracleMock = new OracleMock(DECIMALS, VERSION);
        console.log("OracleMock deployed at:", address(oracleMock));

        vm.stopBroadcast();
    }
}
