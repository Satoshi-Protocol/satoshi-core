// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SegmentVault} from "../../src/vault/SegmentVault.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {INYMVault} from "../../src/interfaces/vault/INYMVault.sol";
import {INexusYieldManager} from "../../src/interfaces/core/INexusYieldManager.sol";
import {SatoshiMath} from "../../src/dependencies/SatoshiMath.sol";

contract DeploySegmentVaultScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address constant stableTokenAddress = 0x05D032ac25d322df992303dCa074EE7392C117b9; // usdt
    address constant owner = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
    address constant whale = 0xCD46Ca375E3c67A99c2F4cd8284c73d9D777d21C;
    address constant lendingPool = 0x7414f14497be308e30ee345A0dcfC43623C179c2; // segment SeBep20Delegate
    address constant nexusYieldManager = 0x7253493c3259137431a120752e410b38d0c715C2;
    SegmentVault segmentVault = SegmentVault(0x81f28090F67545A201f9AF6a4F2bc1b3E8288e46);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        uint256 amount = 7000e6;

        vm.startBroadcast(OWNER_PRIVATE_KEY);
        // SegmentVault segmentVaultImpl = new SegmentVault();
        // ISatoshiCore _satoshiCore = ISatoshiCore(address(new SatoshiCore(owner, owner, owner, owner)));

        // bytes memory initializeData = abi.encode(_satoshiCore, stableTokenAddress);
        // bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));
        // address proxy = address(new ERC1967Proxy(address(segmentVaultImpl), data));
        // segmentVault = SegmentVault(proxy);
        // segmentVault.setStrategyAddr(lendingPool);
        // segmentVault.setNYMAddr(owner);

        // INexusYieldManager(nexusYieldManager).setPrivileged(address(segmentVault), true);
        INexusYieldManager(nexusYieldManager).transerTokenToPrivilegedVault(
            stableTokenAddress, address(segmentVault), amount
        );
        bytes memory data = abi.encode(amount);
        segmentVault.executeStrategy(data);

        uint256 seTokenBalance = IERC20(lendingPool).balanceOf(address(segmentVault));

        // bytes memory data = abi.encode(seTokenBalance);
        // segmentVault.exitStrategy(data);

        // console.log("SegmentVault deployed at: ", address(segmentVault));
        console.log("SegmentVault balance: ", seTokenBalance);
        // console.log("USDT balance: ", IERC20(stableTokenAddress).balanceOf(address(segmentVault)));

        vm.stopBroadcast();
    }
}
