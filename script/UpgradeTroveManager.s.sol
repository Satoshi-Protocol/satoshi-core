// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {IStabilityPool} from "../src/interfaces/core/IStabilityPool.sol";
import {IFactory} from "../src/interfaces/core/IFactory.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {ICommunityIssuance} from "../src/interfaces/core/ICommunityIssuance.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";
import {IBorrowerOperations} from "../src/interfaces/core/IBorrowerOperations.sol";
import {IWETH} from "../src/helpers/interfaces/IWETH.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {SatoshiPeriphery} from "../src/helpers/SatoshiPeriphery.sol";
import {TroveManager} from "../src/core/TroveManager.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract UpgradeTroveManagerScript is Script {
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    // ISatoshiPeriphery satoshiPeriphery;
    // IDebtToken debtToken = IDebtToken(0xF2692468666E459D87052f68aE474E36C1a34fbB);
    // IBorrowerOperations borrowerOperationsProxy = IBorrowerOperations(0xaA1774e83127C741Fc7dA68550E6C17b3b2B5AcB);
    // ITroveManager troveManagerBeaconProxy = ITroveManager(0x0598Ef47508Ec11a503670Ac3B642AAE8EAEdEFA);
    IBeacon troveManagerBeacon = IBeacon(0x63B7EF90fE90ef771401b6E19B49a8aBDDF1cB8C);
    // address constant WETH_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;
    // address _borrower = 0x381ECcaa34B11f9d83511877c27150CC38D71499;

    function setUp() public {
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        ITroveManager newTroveManagerImpl = new TroveManager();

        console.log("current TroveManager Impl is deployed at", address(troveManagerBeacon.implementation()));
        // upgrade to new trove manager implementation
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
        // require(troveManagerBeacon.implementation() == address(newTroveManagerImpl), "implementation is not matched");

        // (uint256 coll, uint256 debt) = troveManagerBeaconProxy.getTroveCollAndDebt(_borrower);
        // require(coll == 20500000000000000, "coll is not greater than 0");
        // require(debt > 163387271805345521453, "debt is not greater than 0");
        // console.log("coll", coll);
        // console.log("debt", debt);

        // console.log("new TroveManager Impl is deployed at", address(newTroveManagerImpl));

        vm.stopBroadcast();
    }
}
