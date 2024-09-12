// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {DebtToken} from "../src/core/DebtToken.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";

contract UpgradeDebtTokenScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    address constant debtTokenAddr = 0xa1e63CB2CE698CfD3c2Ac6704813e3b870FEDADf;
    string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin";
    string constant DEBT_TOKEN_SYMBOL = "satUSD";

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);

        DebtToken debtTokenImpl = new DebtToken();

        DebtToken debtTokenProxy = DebtToken(debtTokenAddr);

        debtTokenProxy.upgradeTo(address(debtTokenImpl));

        console.log(debtTokenProxy.name());
        console.log(debtTokenProxy.symbol());

        console.log("new Impl is deployed at", address(debtTokenProxy));

        vm.stopBroadcast();
    }
}
