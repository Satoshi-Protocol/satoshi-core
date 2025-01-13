// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AvalonVault} from "../src/vault/AvalonVault.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {VaultManager} from "../src/vault/VaultManager.sol";
import {TroveManager} from "../src/core/TroveManager.sol";
import {PellVault} from "../src/vault/PellVault.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {INYMVault} from "../src/interfaces/vault/INYMVault.sol";
import {IVaultManager} from "../src/interfaces/vault/IVaultManager.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract DeployVaultManagerScript is Script {
    uint256 internal OWNER_PRIVATE_KEY;
    uint256 internal DEPLOYMENT_PRIVATE_KEY;
    address constant tokenAddress = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3; // WBTC
    address constant uBTC = 0x796e4D53067FF374B89b2Ac101ce0c1f72ccaAc2; // uBTC on B2
    address constant uBTCStrategy = 0x92D374dd17F8416c8129f5Efa81f28E0926a60B7;
    address constant uBTCTroveManager = 0xc6F361db5eC432E95D0A08A9Fbe0d7412971cE6c;
    address constant OWNER = 0xf08285dFbd8a7F0b6A4Cd63C4aA667391b035678;
    address constant deployer = 0xeB72400276ecB2757432129eC2D2341Fbc2508F8;
    address constant whale = 0xBDFedF992128CbF10974DC935976116e10665Cc9; // TroveManager
    address constant lendingPool = 0x35B3F1BFe7cbE1e95A3DC2Ad054eB6f0D4c879b6; // Avalon BOB lending pool
    address constant strategyManager = 0x00B67E4805138325ce871D5E27DC15f994681bC1; // StrategyManagerV2
    address constant delegationManager = 0x230B442c0802fE83DAf3d2656aaDFD16ca1E1F66; // DelegationManager
    address constant debtToken = 0x78Fea795cBFcC5fFD6Fb5B845a4f53d25C283bDB; // satUSD
    ISatoshiCore satoshiCore = ISatoshiCore(0x2c929d8DFC5915Af4115f158CcaFf5dcA41F5feD);
    IBeacon troveManagerBeacon = IBeacon(0x5360f7eC26F4d8EE3Ed69DF4ac45589c12b49696);
    ITroveManager troveManager = ITroveManager(uBTCTroveManager);
    AvalonVault avalonVault;
    IVaultManager vaultManagerProxy;
    PellVault pellVault;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
        DEPLOYMENT_PRIVATE_KEY = uint256(vm.envBytes32("DEPLOYMENT_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(DEPLOYMENT_PRIVATE_KEY);

        _deployVaultManager();
        _deployPellVault();

        console.log("VaultManager: ", address(vaultManagerProxy));
        console.log("PellVault: ", address(pellVault));

        vm.stopBroadcast();

        vm.startBroadcast(OWNER_PRIVATE_KEY);

        troveManager.setVaultManager(address(vaultManagerProxy));

        pellVault.setTokenStrategy(uBTC, uBTCStrategy);

        INYMVault[] memory vaults = new INYMVault[](1);
        vaults[0] = INYMVault(address(pellVault));
        _setVaultManagerWL(uBTCTroveManager, vaults);
        _execute();

        console.log(pellVault.getPosition(uBTC));

        vm.stopBroadcast();
    }

    function _upgradeTroveManager() internal {
        ITroveManager newTroveManagerImpl = new TroveManager();
        troveManagerBeacon.upgradeTo(address(newTroveManagerImpl));
    }

    function _deployVaultManager() internal returns (address) {
        VaultManager vaultManagerImpl = new VaultManager();
        assert(vaultManagerProxy == IVaultManager(address(0)));
        bytes memory data = abi.encodeCall(IVaultManager.initialize, (satoshiCore, debtToken));
        vaultManagerProxy = IVaultManager(address(new ERC1967Proxy(address(vaultManagerImpl), data)));

        console.log("vaultManagerImpl: ", address(vaultManagerImpl));

        return address(vaultManagerProxy);
    }

    function _deployAvalonVault() internal returns (address) {
        AvalonVault avalonVaultImpl = new AvalonVault();

        bytes memory initializeData = abi.encode(satoshiCore, tokenAddress, address(vaultManagerProxy));
        bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(avalonVaultImpl), data));
        avalonVault = AvalonVault(proxy);

        console.log("avalonVaultImpl: ", address(avalonVaultImpl));

        return address(avalonVault);
    }

    function _deployPellVault() internal returns (address) {
        PellVault pellVaultImpl = new PellVault();

        bytes memory initializeData =
            abi.encode(satoshiCore, address(vaultManagerProxy), strategyManager, delegationManager);
        bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(pellVaultImpl), data));
        pellVault = PellVault(proxy);

        return address(pellVault);
    }

    function _setCDPFarming() internal {
        troveManager.setFarmingParams(3000, 3500);
        troveManager.setVaultManager(address(vaultManagerProxy));
    }

    function _setVaultManagerWL(address troveManager_, INYMVault[] memory vaults) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            vaultManagerProxy.setWhiteListVault(address(vaults[i]), true);
        }
        // vaultManagerProxy.setPriority(troveManager_, vaults);
    }

    function _execute() internal {
        uint256 farmingAmount = 0.001e8;

        troveManager.transferCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assert(IERC20(uBTC).balanceOf(address(vaultManagerProxy)) == farmingAmount);

        bytes memory data = pellVault.constructDepositData(uBTC, farmingAmount);
        vaultManagerProxy.executeStrategy(address(pellVault), data);
    }
}
