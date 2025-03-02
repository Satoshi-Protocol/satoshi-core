// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";

contract UpgradeRMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address rewardManagerProxyAddr = 0x023739ff540052927Fde6A4b7154Ce3fFc9382B8;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        RewardManager rewardManagerProxy = RewardManager(rewardManagerProxyAddr);

        // IRewardManager rewardManagerImpl = new RewardManager();
        // rewardManagerProxy.upgradeTo(address(rewardManagerImpl));
        rewardManagerProxy.upgradeTo(0x72E1dA7Eba1030f98F441cF19C69fBbCf3121713);

        // console.log("new RewardManager Impl is deployed at", address(rewardManagerImpl));

        vm.stopBroadcast();
    }
}
