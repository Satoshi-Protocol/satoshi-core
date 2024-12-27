// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PellVault} from "../../src/vault/PellVault.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {VaultManager} from "../../src/vault/VaultManager.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICDPVault} from "../../src/interfaces/vault/ICDPVault.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {ITroveManager} from "../../src/interfaces/core/ITroveManager.sol";
import {INYMVault} from "../../src/interfaces/vault/INYMVault.sol";
import {IVaultManager} from "../../src/interfaces/vault/IVaultManager.sol";

contract PellVaultTest is Test {
    address constant tokenAddress = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3; // WBTC
    address constant OWNER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
    address constant deployer = 0x15F1fDBA8C05B594eFfDE3CCdaC0133981eD18b7;
    address constant whale = 0xBDFedF992128CbF10974DC935976116e10665Cc9; // TroveManager
    address constant lendingPool = 0x00B67E4805138325ce871D5E27DC15f994681bC1; // StrategyManagerV2
    address constant pellStrategy = 0x92D374dd17F8416c8129f5Efa81f28E0926a60B7;
    address constant avalonVault = 0x713dD0E14376a6d34D0Fde2783dca52c9fD852bA;
    ISatoshiCore satoshiCore = ISatoshiCore(0xd6dBF24f3516844b02Ad8d7DaC9656F2EC556639);
    ITroveManager troveManager = ITroveManager(whale);
    IVaultManager vaultManagerProxy = IVaultManager(0x6a67CFD9b8800B7d1093E4C7e84E5346ec88240F);
    PellVault pellVault;

    function setUp() public {
        vm.createSelectFork(vm.envString("BOB_RPC_URL"));

        vm.startPrank(deployer);
        _deployPellVault();
        vm.stopPrank();

        vm.startPrank(OWNER);

        pellVault.setStrategyAddr(lendingPool);

        INYMVault[] memory vaults = new INYMVault[](2);
        vaults[0] = INYMVault(address(pellVault));
        vaults[1] = INYMVault(avalonVault);
        _setVaultManagerWL(vaults);

        vm.stopPrank();
    }

    function _deployVaultManager() internal returns (address) {
        VaultManager vaultManagerImpl = new VaultManager();
        assert(vaultManagerProxy == IVaultManager(address(0)));
        bytes memory data = abi.encodeCall(IVaultManager.initialize, (satoshiCore, address(troveManager)));
        vaultManagerProxy = IVaultManager(address(new ERC1967Proxy(address(vaultManagerImpl), data)));

        return address(vaultManagerProxy);
    }

    function _deployPellVault() internal returns (address) {
        PellVault pellVaultImpl = new PellVault();

        bytes memory initializeData = abi.encode(satoshiCore, tokenAddress, address(vaultManagerProxy), pellStrategy);
        bytes memory data = abi.encodeCall(ICDPVault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(pellVaultImpl), data));
        pellVault = PellVault(proxy);

        return address(pellVault);
    }

    function _setCDPFarming() internal {
        troveManager.setFarmingParams(3000, 3500);
        troveManager.setVaultManager(address(vaultManagerProxy));
    }

    function _setVaultManagerWL(INYMVault[] memory vaults) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            vaultManagerProxy.setWhiteListVault(address(vaults[i]), true);
        }
        vaultManagerProxy.setPriority(vaults);
    }

    function test_executeAndExitStrategyPell_VaultManager() public {
        uint256 farmingAmount = 0.0005e8;
        vm.startPrank(OWNER);
        troveManager.transferCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), farmingAmount);

        vaultManagerProxy.executeStrategy(address(pellVault), farmingAmount);
        assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), 0);

        vaultManagerProxy.exitStrategy(address(pellVault), farmingAmount);
        // assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), farmingAmount);
        vm.stopPrank();
    }
}
