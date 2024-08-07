// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {RewardManager} from "../src/OSHI/RewardManager.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";

contract UpgradeRMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address rewardManagerProxyAddr = 0x5C85670c52AC0B135C84747B16B1d845007a2437;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        uint256 f_coll_before = rewardManagerProxy.F_COLL();

        IRewardManager rewardManagerImpl = new RewardManager();
        RewardManager rewardManagerProxy = RewardManager(rewardManagerProxyAddr);
        rewardManagerProxy.upgradeTo(address(rewardManagerImpl));

        assert(rewardManagerProxy.F_COLL() == f_coll_before);

        console.log("new RewardManager Impl is deployed at", address(rewardManagerImpl));

        vm.stopBroadcast();
    }
}
