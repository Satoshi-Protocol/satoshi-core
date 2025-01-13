// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {PellVault} from "../../src/vault/PellVault.sol";
import {SatoshiCore} from "../../src/core/SatoshiCore.sol";
import {VaultManager} from "../../src/vault/VaultManager.sol";
import {TroveManager} from "../../src/core/TroveManager.sol";
import {UniV3DexVault} from "../../src/vault/UniswapV3Vault.sol";
import {TickHelper} from "../../src/dependencies/uniswapV3/TickHelper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../../src/interfaces/core/ISatoshiCore.sol";
import {ITroveManager} from "../../src/interfaces/core/ITroveManager.sol";
import {INYMVault} from "../../src/interfaces/vault/INYMVault.sol";
import {IVaultManager} from "../../src/interfaces/vault/IVaultManager.sol";
import {INexusYieldManager} from "../../src/interfaces/core/INexusYieldManager.sol";
import {IDebtToken} from "../../src/interfaces/core/IDebtToken.sol";
import {INonfungiblePositionManager} from "../../src/interfaces/dependencies/uniswapV3/INonfungiblePositionManager.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract OkuVaultTest is Test {
    struct PositionVars {
        uint96 nonce;
        address operator;
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    struct Vars {
        uint256 tokenId;
        uint256 token0Amount;
        uint256 token1Amount;
        int24 tickLower;
        int24 tickUpper;
    }

    address constant tokenAddress = 0x05D032ac25d322df992303dCa074EE7392C117b9; // USDT token0
    address constant OWNER = 0x6510b482312e528fbb892b7C3A0d29e07E12DEc3;
    address constant deployer = 0x15F1fDBA8C05B594eFfDE3CCdaC0133981eD18b7;
    ISatoshiCore satoshiCore = ISatoshiCore(0xd6dBF24f3516844b02Ad8d7DaC9656F2EC556639);
    address constant debtToken = 0x78Fea795cBFcC5fFD6Fb5B845a4f53d25C283bDB; // satUSD token1
    address constant nexusYieldManager = 0x7253493c3259137431a120752e410b38d0c715C2;
    address constant nonFungiblePositionManager = 0x743E03cceB4af2efA3CC76838f6E8B50B63F184c;
    IVaultManager vaultManagerProxy;
    UniV3DexVault okuVaultProxy;

    function setUp() public {
        vm.createSelectFork(vm.envString("BOB_RPC_URL"));

        vm.startPrank(deployer);
        _deployVaultManager();
        _deployOkuVault();
        vm.stopPrank();

        vm.label(address(vaultManagerProxy), "VaultManager");
        vm.label(address(okuVaultProxy), "OkuVault");
        vm.label(tokenAddress, "USDT");
        vm.label(debtToken, "satUSD");

        vm.startPrank(OWNER);

        INYMVault[] memory vaults = new INYMVault[](1);
        vaults[0] = INYMVault(address(okuVaultProxy));
        _setVaultManagerWL(vaults);
        _setNYMPrivilegedVaults(address(vaultManagerProxy));
        _setDebtTokenRely(address(vaultManagerProxy));
        vm.stopPrank();
    }

    function _deployVaultManager() internal returns (address) {
        VaultManager vaultManagerImpl = new VaultManager();
        assert(vaultManagerProxy == IVaultManager(address(0)));
        bytes memory data = abi.encodeCall(IVaultManager.initialize, (satoshiCore, debtToken));
        vaultManagerProxy = IVaultManager(address(new ERC1967Proxy(address(vaultManagerImpl), data)));

        return address(vaultManagerProxy);
    }

    function _deployOkuVault() internal returns (address) {
        UniV3DexVault uniV3DexVaultImpl = new UniV3DexVault();
        bytes memory initializeData =
            abi.encode(satoshiCore, debtToken, address(vaultManagerProxy), nonFungiblePositionManager);
        bytes memory data = abi.encodeCall(INYMVault.initialize, (initializeData));

        address proxy = address(new ERC1967Proxy(address(uniV3DexVaultImpl), data));
        okuVaultProxy = UniV3DexVault(proxy);

        return address(okuVaultProxy);
    }

    function _setVaultManagerWL(INYMVault[] memory vaults) internal {
        for (uint256 i = 0; i < vaults.length; i++) {
            vaultManagerProxy.setWhiteListVault(address(vaults[i]), true);
        }
    }

    function _setNYMPrivilegedVaults(address vault) internal {
        INexusYieldManager(nexusYieldManager).setPrivileged(vault, true);
    }

    function _setDebtTokenRely(address vault) internal {
        IDebtToken(debtToken).rely(vault);
    }

    function test_mintNewPosition() public {
        PositionVars memory positionVars;
        Vars memory vars;
        vm.startPrank(OWNER);
        vars.token0Amount = 1e6;
        vars.token1Amount = 1e18;
        vars.tickLower = 276300;
        vars.tickUpper = 276420;

        INexusYieldManager(nexusYieldManager).transerTokenToPrivilegedVault(
            tokenAddress, address(vaultManagerProxy), vars.token0Amount
        );

        bytes memory data = okuVaultProxy.constructMintPositionData(
            tokenAddress,
            debtToken,
            TickHelper.FEE_MEDIUM,
            vars.tickLower,
            vars.tickUpper,
            vars.token0Amount,
            vars.token1Amount,
            0,
            0
        );
        vaultManagerProxy.executeStrategy(address(okuVaultProxy), data);

        // check nft position
        assertEq(IERC721(nonFungiblePositionManager).balanceOf(address(okuVaultProxy)), 1);
        vars.tokenId = okuVaultProxy.tokenIds(0);
        assertEq(IERC721(nonFungiblePositionManager).ownerOf(vars.tokenId), address(okuVaultProxy));
        (
            ,
            ,
            positionVars.token0,
            positionVars.token1,
            positionVars.fee,
            positionVars.tickLower,
            positionVars.tickUpper,
            positionVars.liquidity,
            ,
            ,
            ,
        ) = INonfungiblePositionManager(nonFungiblePositionManager).positions(vars.tokenId);

        assertEq(positionVars.tickLower, vars.tickLower);
        assertEq(positionVars.tickUpper, vars.tickUpper);
        assertEq(positionVars.token0, tokenAddress);
        assertEq(positionVars.token1, debtToken);

        // check the liquidity

        // remove all liquidity
        data = abi.encode(UniV3DexVault.Option.RemoveLiquidityFull, vars.tokenId, 0, 0);

        vaultManagerProxy.executeStrategy(address(okuVaultProxy), data);

        (,,,,,,, positionVars.liquidity,,,,) =
            INonfungiblePositionManager(nonFungiblePositionManager).positions(vars.tokenId);

        assertEq(positionVars.liquidity, 0);

        vm.stopPrank();
    }
}
