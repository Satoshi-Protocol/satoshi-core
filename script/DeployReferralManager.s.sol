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
import {IReferralManager} from "../src/helpers/interfaces/IReferralManager.sol";
import {ReferralManager} from "../src/helpers/ReferralManager.sol";
import {REFERRAL_START_TIMESTAMP, REFERRAL_END_TIMESTAMP} from "./DeploySetupConfig.sol";

contract DeployReferralManagerScript is Script {
    uint256 internal DEPLOYER_PRIVATE_KEY;
    ISatoshiBORouter satoshiBORouter;
    IReferralManager referralManager;
    IDebtToken debtToken = IDebtToken(0xF2692468666E459D87052f68aE474E36C1a34fbB);
    IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0xaA1774e83127C741Fc7dA68550E6C17b3b2B5AcB);
    address constant WETH_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;
    address cpReferralManagerAddr;
    address cpSatoshiBORouterAddr;

    function setUp() public {
        DEPLOYER_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYER_PRIVATE_KEY);

        address deployer = vm.addr(DEPLOYER_PRIVATE_KEY);
        uint64 nonce = vm.getNonce(deployer);

        cpSatoshiBORouterAddr = vm.computeCreateAddress(deployer, nonce);
        cpReferralManagerAddr = vm.computeCreateAddress(deployer, ++nonce);

        satoshiBORouter = new SatoshiBORouter(
            debtToken, borrowerOperationsProxy, IReferralManager(cpReferralManagerAddr), IWETH(WETH_ADDRESS)
        );
        assert(address(satoshiBORouter) == cpSatoshiBORouterAddr);

        referralManager = new ReferralManager(satoshiBORouter, REFERRAL_START_TIMESTAMP, REFERRAL_END_TIMESTAMP);
        assert(address(referralManager) == cpReferralManagerAddr);

        console.log("SatoshiBORouter deployed at: ", address(satoshiBORouter));
        console.log("referralManager deployed at: ", address(referralManager));

        vm.stopBroadcast();
    }
}
