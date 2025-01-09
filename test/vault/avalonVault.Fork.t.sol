// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {AvalonVault} from "../../src/vault/AvalonVault.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {VaultManager} from "../../src/vault/VaultManager.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {ITroveManager} from "../../src/interfaces/core/ITroveManager.sol";
import {INYMVault} from "../../src/interfaces/vault/INYMVault.sol";
import {IVaultManager} from "../../src/interfaces/vault/IVaultManager.sol";

interface IBeacon {
    function upgradeTo(address newImplementation) external;
    function implementation() external view returns (address);
}

contract AvalonVaultTest is Test {
    address constant tokenAddress = 0x03C7054BCB39f7b2e5B2c7AcB37583e32D70Cfa3; // WBTC
    address constant OWNER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
    address constant deployer = 0x15F1fDBA8C05B594eFfDE3CCdaC0133981eD18b7;
    address constant whale = 0xBDFedF992128CbF10974DC935976116e10665Cc9; // TroveManager
    address constant lendingPool = 0x35B3F1BFe7cbE1e95A3DC2Ad054eB6f0D4c879b6; // Avalon BOB lending pool
    address constant debtToken = 0x78Fea795cBFcC5fFD6Fb5B845a4f53d25C283bDB; // satUSD
    ISatoshiCore satoshiCore = ISatoshiCore(0xd6dBF24f3516844b02Ad8d7DaC9656F2EC556639);
    IBeacon troveManagerBeacon = IBeacon(0xabF995EA0AE56b7C62E6bd9A61569395030ca678);
    ITroveManager troveManager = ITroveManager(whale);
    AvalonVault avalonVault;
    IVaultManager vaultManagerProxy;

    function setUp() public {
        vm.createSelectFork(vm.envString("BOB_RPC_URL"));

        vm.startPrank(deployer);
        _deployVaultManager();
        _deployAvalonVault();
        vm.stopPrank();

        vm.label(address(vaultManagerProxy), "VaultManager");
        vm.label(address(avalonVault), "AvalonVault");
        vm.label(whale, "TroveManager");
        vm.label(tokenAddress, "WBTC");

        vm.startPrank(OWNER);

        _setCDPFarming();

        avalonVault.setTokenStrategy(tokenAddress, lendingPool);

        INYMVault[] memory vaults = new INYMVault[](1);
        vaults[0] = INYMVault(address(avalonVault));
        _setVaultManagerWL(vaults);

        vm.stopPrank();
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

        return address(vaultManagerProxy);
    }

    function _deployAvalonVault() internal returns (address) {
        AvalonVault avalonVaultImpl = new AvalonVault();
        bytes memory initializeData = abi.encode(satoshiCore, address(vaultManagerProxy));
        bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(avalonVaultImpl), data));
        avalonVault = AvalonVault(proxy);

        return address(avalonVault);
    }

    function _setCDPFarming() internal {
        troveManager.setFarmingParams(3000, 3500);
        troveManager.setVaultManager(address(vaultManagerProxy));
    }

    function _setVaultManagerWL(INYMVault[] memory vaults) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            vaultManagerProxy.setWhiteListVault(address(vaults[i]), true);
        }
        vaultManagerProxy.setPriority(tokenAddress, vaults);
    }

    function test_supplyAndWithdraw() public {
        uint256 farmingAmount = 0.001e8;
        vm.startPrank(OWNER);
        troveManager.transferCollToPrivilegedVault(address(vaultManagerProxy), farmingAmount);
        assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), farmingAmount);

        bytes memory data = avalonVault.constructSupplyData(tokenAddress, farmingAmount);
        vaultManagerProxy.executeStrategy(address(avalonVault), data);
        assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), 0);

        data = avalonVault.constructWithdrawData(tokenAddress, farmingAmount);
        vaultManagerProxy.executeStrategy(address(avalonVault), data);
        assertEq(IERC20(tokenAddress).balanceOf(address(vaultManagerProxy)), farmingAmount);
        vm.stopPrank();
    }
}
