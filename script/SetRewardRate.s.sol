// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";

contract DeploySetupScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address internal satoshiCoreOwner;
    uint128 internal SP_REWARD_RATE = 63419583967529168; // 10_000_000e18 / (5 * 31536000)
    uint128 internal TM_MAX_REWARD_RATE = 126839167935058336; // 20_000_000e18 / (5 * 31536000)
    uint256 internal TM_ALLOCATION = 20 * 1e24;
    IStabilityPool stabilityPool;
    IFactory factory;
    ITroveManager troveManager;
    ICommunityIssuance communityIssuance;
    address constant troveManagerAddr = 0x445c7a1a5ad3bE01E915Dbbf8E6c142c4FB07f99;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        satoshiCoreOwner = vm.addr(OWNER_PRIVATE_KEY);
        stabilityPool = IStabilityPool(0x5C85670c52AC0B135C84747B16B1d845007a2437);
        factory = IFactory(0xC3144471bD68ACC2ab108819CFDf8548543176A5);
        troveManager = ITroveManager(troveManagerAddr);
        communityIssuance = ICommunityIssuance(0xD70Be421183df64B26e5f2A13937C3A0C04FC022);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        // set SP reward rate
        stabilityPool.setRewardRate(SP_REWARD_RATE);
        require(stabilityPool.rewardRate() == SP_REWARD_RATE, "SP Reward rate not set correctly");
        
        // set trove reward rate
        uint128[] memory numerator = new uint128[](1);
        numerator[0] = 1;
        factory.setRewardRate(numerator, 1);
        require(troveManager.rewardRate() == TM_MAX_REWARD_RATE, "Trove Manager Reward rate not set correctly");
        // set allocated in Community Issuance
        address[] memory _recipients = new address[](1);
        _recipients[0] = troveManagerAddr;
        uint256[] memory _amounts = new uint256[](1);
        _amounts[0] = TM_ALLOCATION;
        communityIssuance.setAllocated(_recipients, _amounts);
        require(communityIssuance.allocated(troveManagerAddr) == TM_ALLOCATION, "Community Issuance allocation not set correctly");

        vm.stopBroadcast();
    }

}