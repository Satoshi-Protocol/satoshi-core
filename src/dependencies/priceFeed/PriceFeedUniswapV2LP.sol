// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint256);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint256);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

/**
 * @title PriceFeed Contract to integrate with UniswapV2 LP
 */
contract PriceFeedUniswapV2LPOracle is SatoshiOwnable {
    using FixedPointMathLib for uint256;

    uint256 public constant TARGET_DIGITS = 18;

    IUniswapV2Pair internal immutable pair;
    IPriceFeed oracle0;
    IPriceFeed oracle1;
    uint8 internal immutable _decimals;

    constructor(address pair_, address oracle0_, address oracle1_, uint8 decimals_, ISatoshiCore _satoshiCore) {
        __SatoshiOwnable_init(_satoshiCore);
        pair = IUniswapV2Pair(pair_);
        _decimals = decimals_;
        oracle0 = IPriceFeed(oracle0_);
        oracle1 = IPriceFeed(oracle1_);
    }

    /// @dev Adapted from https://blog.alphaventuredao.io/fair-lp-token-pricing
    function fetchPrice() external returns (uint256) {
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(pair).getReserves();

        {
            address token0 = IUniswapV2Pair(pair).token0();
            address token1 = IUniswapV2Pair(pair).token1();

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

        uint256 price0 = _getScaledPrice(oracle0.fetchPrice(), oracle0.decimals());
        uint256 price1 = _getScaledPrice(oracle1.fetchPrice(), oracle1.decimals());

        // 2 * sqrt(r0 * r1 * p0 * p1) / totalSupply
        return 2 * FixedPointMathLib.sqrt(r0 * price0) * FixedPointMathLib.sqrt(r1 * price1)
            / IUniswapV2Pair(pair).totalSupply();
    }

    function fetchPriceUnsafe() external returns (uint256, uint256) {
        (uint256 r0, uint256 r1,) = IUniswapV2Pair(pair).getReserves();

        {
            address token0 = IUniswapV2Pair(pair).token0();
            address token1 = IUniswapV2Pair(pair).token1();

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

        (uint256 rawPrice0, uint256 lastUpdate0) = oracle0.fetchPriceUnsafe();
        (uint256 rawPrice1, uint256 lastUpdate1) = oracle1.fetchPriceUnsafe();

        uint256 price0 = _getScaledPrice(rawPrice0, oracle0.decimals());
        uint256 price1 = _getScaledPrice(rawPrice1, oracle1.decimals());

        // 2 * sqrt(r0 * r1 * p0 * p1) / totalSupply
        uint256 lpPrice = 2 * FixedPointMathLib.sqrt(r0 * price0) * FixedPointMathLib.sqrt(r1 * price1)
            / IUniswapV2Pair(pair).totalSupply();

        return (lpPrice, lastUpdate0 > lastUpdate1 ? lastUpdate0 : lastUpdate1);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function source() external view returns (address) {
        return address(pair);
    }

    function _getScaledPrice(uint256 rawPrice, uint256 decimal) internal pure returns (uint256 scaledPrice) {
        if (decimal == TARGET_DIGITS) {
            scaledPrice = rawPrice;
        } else if (decimal < TARGET_DIGITS) {
            scaledPrice = rawPrice * (10 ** (TARGET_DIGITS - decimal));
        } else {
            scaledPrice = rawPrice / (10 ** (decimal - TARGET_DIGITS));
        }
    }
}
