// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LiquidationManager} from "../src/core/LiquidationManager.sol";
import {ILiquidationManager} from "../src/interfaces/core/ILiquidationManager.sol";

contract UpgradeLiquidationManagerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address liquidationManagerProxyAddr = 0x31bacB4288A242daC87042EF051F40dB6745921C;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        // deploy new LiquidationManager implementation
        ILiquidationManager newLiquidationManagerImpl = new LiquidationManager();

        // upgrade to new LiquidationManager implementation
        LiquidationManager liquidationManagerProxy = LiquidationManager(liquidationManagerProxyAddr);
        liquidationManagerProxy.upgradeTo(address(newLiquidationManagerImpl));

        console.log("new LiquidationManager Impl is deployed at", address(newLiquidationManagerImpl));
        bytes32 s = vm.load(
            address(liquidationManagerProxy), LiquidationManager(address(newLiquidationManagerImpl)).proxiableUUID()
        );
        // `0x000...address` << 96 -> `0xaddress000...000`
        s <<= 96;
        assert(s == bytes32(bytes20(address(newLiquidationManagerImpl))));
        vm.stopBroadcast();
    }
}
