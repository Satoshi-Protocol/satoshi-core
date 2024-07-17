// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NexusYieldManager} from "../src/core/NexusYieldManager.sol";
import {INexusYieldManager} from "../src/interfaces/core/INexusYieldManager.sol";

contract UpgradeNYMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address nymProxyAddr = 0xdB016f8aE91BF399C581df87E50f22627EC73563;
    address constant debtTokenAddr = 0x942f2071a9A567c5b153b6fbAEB2deAf5cE76208;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        NexusYieldManager nymImpl = new NexusYieldManager(debtTokenAddr);

        NexusYieldManager nymProxy = NexusYieldManager(nymProxyAddr);
        nymProxy.upgradeTo(address(nymImpl));

        console.log("new nym Impl is deployed at", address(nymImpl));

        vm.stopBroadcast();
    }
}
