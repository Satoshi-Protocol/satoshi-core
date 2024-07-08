// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PriceFeedUniswapV2LPOracle, IUniswapV2Pair} from "../src/dependencies/priceFeed/PriceFeedUniswapV2LP.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";
import {PriceFeedChainlink} from "../src/dependencies/priceFeed/PriceFeedChainlink.sol";
import {AggregatorV3Interface} from "../src/interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
}

contract PriceFeedUniV2LPTest is Test {
    uint256 public constant TARGET_DIGITS = 18;
    PriceFeedUniswapV2LPOracle oracle;
    address pool = 0x4028DAAC072e492d34a3Afdbef0ba7e35D8b55C4; // stETH/ETH pool
    address constant owner = 0xE79c8DBe6D08b85C7B47140C8c10AF5C62678b4a;
    address oracle1 = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419; // eth
    address oracle2 = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8; // steth
    PriceFeedChainlink priceFeed1;
    PriceFeedChainlink priceFeed2;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
        ISatoshiCore _satoshiCore = ISatoshiCore(address(new SatoshiCore(owner, owner, owner, owner)));
        priceFeed1 = new PriceFeedChainlink(AggregatorV3Interface(oracle1), _satoshiCore);
        priceFeed2 = new PriceFeedChainlink(AggregatorV3Interface(oracle2), _satoshiCore);
        oracle = new PriceFeedUniswapV2LPOracle(pool, address(priceFeed1), address(priceFeed2), 18, _satoshiCore);
    }

    function test_UniV2fetchPrice() public {
        uint256 price = oracle.fetchPrice();
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(pool).getReserves();

        {
            address token0 = IUniswapV2Pair(pool).token0();
            address token1 = IUniswapV2Pair(pool).token1();

            uint256 decimals0 = IERC20(token0).decimals();
            uint256 decimals1 = IERC20(token1).decimals();

            if (decimals0 <= TARGET_DIGITS) {
                r0 = r0 * 10 ** (TARGET_DIGITS - decimals0);
            } else {
                r0 = r0 / 10 ** (decimals0 - TARGET_DIGITS);
            }

            if (decimals1 <= TARGET_DIGITS) {
                r1 = r1 * 10 ** (TARGET_DIGITS - decimals1);
            } else {
                r1 = r1 / 10 ** (decimals1 - TARGET_DIGITS);
            }
        }

        uint256 expectedPrice = (
            r0 * priceFeed2.fetchPrice() * 10 ** (18 - priceFeed2.decimals())
                + r1 * priceFeed1.fetchPrice() * 10 ** (18 - priceFeed1.decimals())
        ) / IUniswapV2Pair(pool).totalSupply();

        assertApproxEqAbs(price, expectedPrice, 1e17);
    }

    function test_UniV2fetchPriceUnsafe() public {
        (uint256 price,) = oracle.fetchPriceUnsafe();
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(pool).getReserves();
        {
            address token0 = IUniswapV2Pair(pool).token0();
            address token1 = IUniswapV2Pair(pool).token1();

            uint256 decimals0 = IERC20(token0).decimals();
            uint256 decimals1 = IERC20(token1).decimals();

            if (decimals0 <= TARGET_DIGITS) {
                r0 = r0 * 10 ** (TARGET_DIGITS - decimals0);
            } else {
                r0 = r0 / 10 ** (decimals0 - TARGET_DIGITS);
            }

            if (decimals1 <= TARGET_DIGITS) {
                r1 = r1 * 10 ** (TARGET_DIGITS - decimals1);
            } else {
                r1 = r1 / 10 ** (decimals1 - TARGET_DIGITS);
            }
        }
        uint256 expectedPrice = (
            r0 * priceFeed2.fetchPrice() * 10 ** (18 - priceFeed2.decimals())
                + r1 * priceFeed1.fetchPrice() * 10 ** (18 - priceFeed1.decimals())
        ) / IUniswapV2Pair(pool).totalSupply();

        assertApproxEqAbs(price, expectedPrice, 1e17);
    }
}
