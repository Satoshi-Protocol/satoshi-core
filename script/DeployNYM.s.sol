// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NexusYieldManager} from "../src/core/NexusYieldManager.sol";
import {INexusYieldManager} from "../src/interfaces/core/INexusYieldManager.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";

contract DeployNYMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address constant debtTokenAddr = 0x9f5bCD3529d3B610BeA2b4E5FE273D1Fc059B8F6;
    ISatoshiCore satoshiCore = ISatoshiCore(0x04d4a0295a7e15941cfDfFbcC5EE97cc1f347CF0);
    address constant rewardManagerProxy = 0xc5624B51890A66E0e36Ab9DbC98a810FD7507da4;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        INexusYieldManager nexusYieldImpl = new NexusYieldManager(debtTokenAddr);

        bytes memory data = abi.encodeCall(INexusYieldManager.initialize, (satoshiCore, address(rewardManagerProxy)));

        INexusYieldManager proxy = INexusYieldManager(address(new ERC1967Proxy(address(nexusYieldImpl), data)));
        console.log("NexusYieldManagerImpl:", address(nexusYieldImpl));
        console.log("NexusYieldManager:", address(proxy));

        vm.stopBroadcast();
    }
}
