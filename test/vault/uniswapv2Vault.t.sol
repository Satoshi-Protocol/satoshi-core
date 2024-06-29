// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ISortedTroves} from "../../src/interfaces/core/ISortedTroves.sol";
import {ITroveManager, TroveManagerOperation} from "../../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {SatoshiMath} from "../../src/dependencies/SatoshiMath.sol";
import {DeployBase, LocalVars} from "../utils/DeployBase.t.sol";
import {HintLib} from "../utils/HintLib.sol";
import {DEPLOYER, OWNER, GAS_COMPENSATION, TestConfig, REWARD_MANAGER, FEE_RECEIVER} from "../TestConfig.sol";
import {TroveBase} from "../utils/TroveBase.t.sol";
import {Events} from "../utils/Events.sol";
import {RoundData} from "../../src/mocks/OracleMock.sol";
import {INTEREST_RATE_IN_BPS} from "../TestConfig.sol";
import {UniV2Vault} from "../../src/vault/uniswapV2Vault.sol";
import {NexusYieldManager} from "../../src/core/NexusYieldManager.sol";
import {INexusYieldManager} from "../../src/interfaces/core/INexusYieldManager.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

contract UniswapV2VaultTest is Test, DeployBase, TroveBase, TestConfig, Events {
    using Math for uint256;

    ISortedTroves sortedTrovesBeaconProxy;
    ITroveManager troveManagerBeaconProxy;
    IMultiCollateralHintHelpers hintHelpers;
    UniV2Vault uniV2Vault;
    IUniswapV2Factory uniswapV2Factory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;
    uint256 maxFeePercentage = 0.05e18; // 5%
    address constant stableTokenAddress = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // usdc
    address pair;
    address router = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant whale = 0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa;

    function setUp() public override {
        vm.createSelectFork("https://eth.llamarpc.com");
        super.setUp();

        // testing user
        user1 = vm.addr(1);
        user2 = vm.addr(2);
        user3 = vm.addr(3);
        user4 = vm.addr(4);
        user5 = vm.addr(5);

        // setup contracts and deploy one instance
        (sortedTrovesBeaconProxy, troveManagerBeaconProxy) = _deploySetupAndInstance(
            DEPLOYER, OWNER, ORACLE_MOCK_DECIMALS, ORACLE_MOCK_VERSION, initRoundData, collateralMock, deploymentParams
        );

        // deploy hint helper contract
        hintHelpers = IMultiCollateralHintHelpers(_deployHintHelpers(DEPLOYER));

        _deployNexusYieldProxy(DEPLOYER);

        vm.startPrank(OWNER);
        nexusYieldProxy.setAssetConfig(stableTokenAddress, 10, 10, 1000000e18, 100000e18, address(0), false, 3 days);
        debtTokenProxy.rely(address(nexusYieldProxy));
        rewardManagerProxy.setWhitelistCaller(address(nexusYieldProxy), true);
        vm.stopPrank();

        // create pair on uniswap v2
        pair = uniswapV2Factory.createPair(stableTokenAddress, address(debtTokenProxy));

        UniV2Vault univ2Vaultimpl = new UniV2Vault();
        bytes memory initializeData = abi.encode(satoshiCore, stableTokenAddress, address(debtTokenProxy), pair);
        bytes memory data =
            abi.encodeCall(UniV2Vault.initialize, (initializeData));
        address proxy = address(new ERC1967Proxy(address(univ2Vaultimpl), data));
        uniV2Vault = UniV2Vault(proxy);

        vm.startPrank(OWNER);
        nexusYieldProxy.setPrivileged(address(uniV2Vault), true);
        uniV2Vault.setNYMAddr(address(nexusYieldProxy));
        uniV2Vault.setStrategyAddr(router);
        vm.stopPrank();

        vm.label(address(uniV2Vault), "uniV2Vault");
        vm.label(pair, "pair");
        vm.label(router, "router");
        vm.label(stableTokenAddress, "USDC");
        vm.label(address(debtTokenProxy), "SAT");
        vm.label(address(nexusYieldProxy), "NYM");

        // swap in
        vm.prank(whale);
        IERC20(stableTokenAddress).transfer(address(this), 100e8);
        IERC20(stableTokenAddress).approve(address(nexusYieldProxy), 100e8);
        nexusYieldProxy.swapStableForSAT(stableTokenAddress, address(this), 100e8);
    }

    function test_executeAndExitStrategyV2() public {
        vm.prank(whale);
        IERC20(stableTokenAddress).transfer(address(uniV2Vault), 100e6);
        assertEq(IERC20(stableTokenAddress).balanceOf(address(uniV2Vault)), 100e6);
        vm.startPrank(OWNER);
        // execute strategy
        bytes memory executeData = abi.encode(5e6, 5e18, 0, 0);
        uniV2Vault.executeStrategy(executeData);
        // exit strategy
        bytes memory exitData = abi.encode(10e10);
        uniV2Vault.exitStrategy(exitData);

        uint256 nymBalance = IERC20(stableTokenAddress).balanceOf(address(nexusYieldProxy));
        uniV2Vault.transferTokenToNYM(100);
        assertEq(IERC20(stableTokenAddress).balanceOf(address(nexusYieldProxy)), nymBalance + 100);

        uniV2Vault.transferToken(stableTokenAddress, user1, 100);
        assertEq(IERC20(stableTokenAddress).balanceOf(user1), 100);
        vm.stopPrank();
    }
}
