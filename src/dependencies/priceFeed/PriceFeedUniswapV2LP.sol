// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../../interfaces/core/ISatoshiCore.sol";
import {IPriceFeed} from "../../interfaces/dependencies/IPriceFeed.sol";
import {SatoshiOwnable} from "../SatoshiOwnable.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

interface IERC20 {
    function decimals() external view returns (uint8);
    function balanceOf(address) external view returns (uint);
}

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function totalSupply() external view returns (uint);
    function getReserves() external view returns (
        uint112 reserve0,
        uint112 reserve1,
        uint32 blockTimestampLast
    );
}

/**
 * @title PriceFeed Contract to integrate with UniswapV2 LP
 */
contract PriceFeedUniswapV2LPOracle is SatoshiOwnable {
    using FixedPointMathLib for uint256;
    IUniswapV2Pair internal immutable pair;
    IPriceFeed oracle1;
    IPriceFeed oracle2;
    uint8 internal immutable _decimals;

    constructor(
        IUniswapV2Pair pair_,
        IPriceFeed oracle1_,
        IPriceFeed oracle2_,
        uint8 decimals_,
        ISatoshiCore _satoshiCore
    ) {
        __SatoshiOwnable_init(_satoshiCore);
        pair = pair_;
        _decimals = decimals_;
        oracle1 = oracle1_;
        oracle2 = oracle2_;
    }

    /// @dev Adapted from https://blog.alphaventuredao.io/fair-lp-token-pricing
    function fetchPrice() external returns (uint256) {
        (uint r0, uint r1,) = IUniswapV2Pair(pair).getReserves();

        {
        address token0 = IUniswapV2Pair(pair).token0();
        address token1 = IUniswapV2Pair(pair).token1();

        uint256 decimals0 = IERC20(token0).decimals();
        uint256 decimals1 = IERC20(token1).decimals();

        if (decimals0 <= 18)
            r0 = r0 * 10 ** (18 - decimals0);
        else r0 = r0 / 10 ** (decimals0 - 18);

        if (decimals1 <= 18)
            r1 = r1 * 10 ** (18 - decimals1);
        else r1 = r1 / 10 ** (decimals1 - 18);
        }

        // 2 * sqrt(r0 * r1 * p0 * p1) / totalSupply
        return FixedPointMathLib.sqrt(
            r0
            .mulWadDown(r1)
            .mulWadDown(oracle1.fetchPrice())
            .mulWadDown(oracle2.fetchPrice())
        ).mulDivDown(2e27, IUniswapV2Pair(pair).totalSupply());
    }

    function fetchPriceUnsafe() external returns (uint256, uint256) {
        (uint r0, uint r1,) = IUniswapV2Pair(pair).getReserves();

        {
            address token0 = IUniswapV2Pair(pair).token0();
            address token1 = IUniswapV2Pair(pair).token1();
    
            uint256 decimals0 = IERC20(token0).decimals();
            uint256 decimals1 = IERC20(token1).decimals();
    
            if (decimals0 <= 18)
                r0 = r0 * 10 ** (18 - decimals0);
            else r0 = r0 / 10 ** (decimals0 - 18);
    
            if (decimals1 <= 18)
                r1 = r1 * 10 ** (18 - decimals1);
            else r1 = r1 / 10 ** (decimals1 - 18);
        }
    
        (uint256 price1, uint256 lastUpdate1) = oracle1.fetchPriceUnsafe();
        (uint256 price2, ) = oracle2.fetchPriceUnsafe();
    
        // 2 * sqrt(r0 * r1 * p0 * p1) / totalSupply
        uint256 lpPrice =  FixedPointMathLib.sqrt(
            r0
            .mulWadDown(r1)
            .mulWadDown(price1)
            .mulWadDown(price2)
        ).mulDivDown(2e27, IUniswapV2Pair(pair).totalSupply());
        return (lpPrice, lastUpdate1);
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function source() external view returns (address) {
        return address(pair);
    }
}
