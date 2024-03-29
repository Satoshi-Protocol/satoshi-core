// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiLPFactory} from "../src/interfaces/core/ISatoshiLPFactory.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {SatoshiLPFactory} from "../src/SLP/SatoshiLPFactory.sol";

contract DeploySLPFactoryScript is Script {
    uint256 internal DEPLOYER_PRIVATE_KEY;
    ISatoshiLPFactory satoshiLPFactory;
    ISatoshiCore satoshiCore = ISatoshiCore(0x365b4915289f2b27dcA58BEBd2960ECDCC2AE3b6);
    ICommunityIssuance communityIssuance = ICommunityIssuance(0xD70Be421183df64B26e5f2A13937C3A0C04FC022);

    function setUp() public {
        DEPLOYER_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        satoshiLPFactory = new SatoshiLPFactory(satoshiCore, communityIssuance);

        console.log("satoshiLPFactory deployed at: ", address(satoshiLPFactory));

        vm.stopBroadcast();
    }
}
