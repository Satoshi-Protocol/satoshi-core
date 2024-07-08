// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StabilityPool} from "../src/core/StabilityPool.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";

contract UpgradeStabilityPoolScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address stabilityPoolProxyAddr = 0x83f39bBC801a986671CBDE807a094A8937155B28;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        // deploy new stability pool implementation
        IStabilityPool newStabilityPoolImpl = new StabilityPool();

        // upgrade to new stability pool implementation
        StabilityPool stabilityPoolProxy = StabilityPool(stabilityPoolProxyAddr);
        stabilityPoolProxy.upgradeTo(address(newStabilityPoolImpl));

        console.log("new StabilityPool Impl is deployed at", address(newStabilityPoolImpl));

        vm.stopBroadcast();
    }
}
