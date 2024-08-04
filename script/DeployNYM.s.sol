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
    SATOSHI_CORE_ADDRESS,
    DEBT_TOKEN_ADDRESS,
    REWARD_MANAGER_PROXY_ADDRESS,
    MAX_PRICE,
    MIN_PRICE
} from "./DeployNYMConfig.sol";

contract DeployNYMScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    INexusYieldManager nym;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        INexusYieldManager nexusYieldImpl = new NexusYieldManager();

        bytes memory data = abi.encodeCall(
            INexusYieldManager.initialize,
            (ISatoshiCore(SATOSHI_CORE_ADDRESS), DEBT_TOKEN_ADDRESS, REWARD_MANAGER_PROXY_ADDRESS)
        );

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
        IDebtToken(DEBT_TOKEN_ADDRESS).rely(address(nym));
        IRewardManager(REWARD_MANAGER_PROXY_ADDRESS).setWhitelistCaller(address(nym), true);
    }
}
