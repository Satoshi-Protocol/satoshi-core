// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {NexusYieldManager} from "../src/core/NexusYieldManager.sol";
import {INexusYieldManager} from "../src/interfaces/core/INexusYieldManager.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IRewardManager} from "../src/interfaces/core/IRewardManager.sol";
import {
    ASSET,
    FEE_IN,
    FEE_OUT,
    MINT_CAP,
    DAILY_MINT_CAP,
    PRICE_AGGREGATOR_PROXY,
    USING_ORACLE,
    SWAP_WAIT_TIME,
    MAX_PRICE,
    MIN_PRICE
} from "./DeployNYMConfig.sol";

contract DeployNYMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address constant debtTokenAddr = 0x942f2071a9A567c5b153b6fbAEB2deAf5cE76208;
    ISatoshiCore satoshiCore = ISatoshiCore(0xA8f683335A38048a82739cd5a996150f1c91B8C1);
    address constant rewardManagerProxy = 0x269EeCEa5E9304fA1bc9361461798134e9AE4A60;
    INexusYieldManager nym;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        INexusYieldManager nexusYieldImpl = new NexusYieldManager(debtTokenAddr);

        bytes memory data = abi.encodeCall(INexusYieldManager.initialize, (satoshiCore, address(rewardManagerProxy)));

        nym = INexusYieldManager(address(new ERC1967Proxy(address(nexusYieldImpl), data)));
        console.log("NexusYieldManagerImpl:", address(nexusYieldImpl));
        console.log("NexusYieldManager:", address(nym));

        vm.stopBroadcast();

        vm.startBroadcast(OWNER_PRIVATE_KEY);

        _setAssetConfig();

        vm.stopBroadcast();
    }

    function _setAssetConfig() internal {
        nym.setAssetConfig(
            ASSET,
            FEE_IN,
            FEE_OUT,
            MINT_CAP,
            DAILY_MINT_CAP,
            PRICE_AGGREGATOR_PROXY,
            USING_ORACLE,
            SWAP_WAIT_TIME,
            MAX_PRICE,
            MIN_PRICE
        );

        // add whitelist
        IDebtToken(debtTokenAddr).rely(address(nym));
        IRewardManager(rewardManagerProxy).setWhitelistCaller(address(nym), true);
    }
}
