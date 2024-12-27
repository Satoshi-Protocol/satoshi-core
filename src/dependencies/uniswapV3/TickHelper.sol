pragma solidity ^0.8.19;

import {TickMath} from "./TickMath.sol";
import {Tick} from "./Tick.sol";

library TickHelper {
    uint24 constant FEE_LOW = 500;
    uint24 constant FEE_MEDIUM = 3000;
    uint24 constant FEE_HIGH = 10000;

    int24 constant TICK_LOW = 10;
    int24 constant TICK_MEDIUM = 60;
    int24 constant TICK_HIGH = 200;

    // mapping(uint24 => int24)  feeAmountTickSpacing;
    // feeAmountTickSpacing[500] = 10;
    //         feeAmountTickSpacing[3000] = 60;
    //         feeAmountTickSpacing[10000] = 200;

    function getMinTick(int24 tickSpacing) internal pure returns (int24) {
        return (TickMath.MIN_TICK / tickSpacing) * tickSpacing;
    }

    function getMaxTick(int24 tickSpacing) internal pure returns (int24) {
        return (TickMath.MAX_TICK / tickSpacing) * tickSpacing;
    }

    function getTick(uint160 sqrtPriceX96) internal pure returns (int24) {
        int24 tick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        require(TickMath.MIN_TICK <= tick && tick < TickMath.MAX_TICK, "Tick out of bounds ");
        return tick;
    }

    function getSqrtRatioAtTick(int24 tick) internal pure returns (uint160) {
        return TickMath.getSqrtRatioAtTick(tick);
    }

    function tickSpacingToMaxLiquidityPerTick(int24 tickSpacing) internal pure returns (uint128) {
        return Tick.tickSpacingToMaxLiquidityPerTick(tickSpacing);
    }
}
