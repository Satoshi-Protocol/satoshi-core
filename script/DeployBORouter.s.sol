// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IReferralManager} from "../src/helpers/interfaces/IReferralManager.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {ISatoshiBORouter} from "../src/helpers/interfaces/ISatoshiBORouter.sol";
import {SatoshiBORouter} from "../src/helpers/SatoshiBORouter.sol";

contract DeployBORouter is Script {
    uint256 internal DEPLOYER_PRIVATE_KEY;
    ISatoshiBORouter satoshiBORouter;
    IReferralManager referralManager = IReferralManager(0xAdDc150C38E165be1F0183564bBB7e51Cb0B2Bb7);
    IDebtToken debtToken = IDebtToken(0xF2692468666E459D87052f68aE474E36C1a34fbB);
    IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0xaA1774e83127C741Fc7dA68550E6C17b3b2B5AcB);
    address constant WETH_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;

    function setUp() public {
        DEPLOYER_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        satoshiBORouter = new SatoshiBORouter(
            debtToken, borrowerOperationsProxy, referralManager, IWETH(WETH_ADDRESS)
        );

        console.log("SatoshiBORouter deployed at: ", address(satoshiBORouter));
        
        vm.stopBroadcast();
    }

}