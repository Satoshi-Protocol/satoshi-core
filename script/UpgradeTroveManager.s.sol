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
import {TroveManager} from "../src/core/TroveManager.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeTroveManagerScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    ISatoshiBORouter satoshiBORouter;
    IReferralManager referralManager;
    IDebtToken debtToken = IDebtToken(0xF2692468666E459D87052f68aE474E36C1a34fbB);
    IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0xaA1774e83127C741Fc7dA68550E6C17b3b2B5AcB);
    ITroveManager troveManagerBeaconProxy = ITroveManager(0x0598Ef47508Ec11a503670Ac3B642AAE8EAEdEFA);
    IBeacon troveManagerBeacon = IBeacon(0x445c7a1a5ad3bE01E915Dbbf8E6c142c4FB07f99);
    address constant WETH_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        ITroveManager newTroveManagerImpl = new TroveManager();

        // upgrade to new trove manager implementation
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
        require(troveManagerBeacon.implementation() == address(newTroveManagerImpl), "implementation is not matched");

        // check the max interest rate
        require(troveManagerBeaconProxy.MAX_INTEREST_RATE_IN_BPS() == 10000, "interst rate is not 10000");

        console.log("new TroveManager Impl is deployed at", address(newTroveManagerImpl));

        vm.stopBroadcast();
    }
}
