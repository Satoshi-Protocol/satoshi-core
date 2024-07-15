// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {IPriceFeedAggregator} from "../../src/interfaces/core/IPriceFeedAggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPriceFeed} from "../../src/interfaces/dependencies/IPriceFeed.sol";

contract SetPriceFeedScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    uint256 internal OWNER_PRIVATE_KEY;
    address public deployer;
    IPriceFeedAggregator priceFeedAggregator = IPriceFeedAggregator(0xB8954C4e7EBCEEF6F00e3003d5B376A78BF7321F);
    IERC20 token = IERC20(0x4F245e278BEC589bAacF36Ba688B412D51874457);
    IPriceFeed priceFeed = IPriceFeed(0x392D7fC75cD354bCf4e75d950F897973eF1b933b);

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
        deployer = vm.addr(DEPLOYMENT_PRIVATE_KEY);
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        priceFeedAggregator.setPriceFeed(token, priceFeed);

        vm.stopBroadcast();
    }
}
