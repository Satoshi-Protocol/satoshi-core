// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AAVEVault} from "../../src/vault/aaveVault.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {INYMVault} from "../../src/interfaces/vault/INYMVault.sol";

contract AAVEVaultTest is Test {
    address constant stableTokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // usdc
    address constant owner = 0xE79c8DBe6D08b85C7B47140C8c10AF5C62678b4a;
    address constant whale = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;
    address constant lendingPool = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9; // aave v2 mainnet lending pool
    AAVEVault aaveVault;

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com");
        AAVEVault aaveVaultImpl = new AAVEVault();
        ISatoshiCore _satoshiCore = ISatoshiCore(address(new SatoshiCore(owner, owner, owner, owner)));

        bytes memory initializeData = abi.encode(_satoshiCore, stableTokenAddress);
        bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(aaveVaultImpl), data));
        aaveVault = AAVEVault(proxy);

        vm.startPrank(owner);
        aaveVault.setStrategyAddr(lendingPool);
        aaveVault.setNYMAddr(owner);
        vm.stopPrank();
    }

    function test_executeAndExitStrategyAAVE() public {
        vm.prank(whale);
        IERC20(stableTokenAddress).transfer(address(aaveVault), 100);
        assertEq(IERC20(stableTokenAddress).balanceOf(address(aaveVault)), 100);

        vm.startPrank(owner);
        bytes memory data = abi.encode(100);
        aaveVault.executeStrategy(data);
        aaveVault.exitStrategy(data);
        assertEq(IERC20(stableTokenAddress).balanceOf(owner), 100);
        vm.stopPrank();
    }
}
