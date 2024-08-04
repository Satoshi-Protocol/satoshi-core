// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";

contract UpgradeRewardManagerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address stabilityPoolProxyAddr = 0xfc8ab0e486F17c78Eaf59A416168d0F89D9373eD;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        // before
        uint256 f_sat_before = IRewardManager(stabilityPoolProxyAddr).F_SAT();

        // deploy new implementation
        IRewardManager newRewardManagerImpl = new RewardManager();

        // upgrade to new implementation
        RewardManager rewardManagerProxy = RewardManager(stabilityPoolProxyAddr);
        rewardManagerProxy.upgradeTo(address(newRewardManagerImpl));

        console.log("new RewardManager Impl is deployed at", address(newRewardManagerImpl));

        // check the storage
        assert(f_sat_before == IRewardManager(stabilityPoolProxyAddr).F_SAT());

        vm.stopBroadcast();
    }
}
