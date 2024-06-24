// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {PriceFeedCurveLPOracle, ICurvePool} from "../src/dependencies/priceFeed/PriceFeedCurveLP.sol";
import {ISatoshiCore} from "../src/interfaces/core/ISatoshiCore.sol";
import {SatoshiCore} from "../src/core/SatoshiCore.sol";

contract PriceFeedCurveLPTest is Test {
    PriceFeedCurveLPOracle oracle;
    address pool = 0xB7ECB2AA52AA64a717180E030241bC75Cd946726; // wbtc/tbtc pool
    address constant owner = 0xE79c8DBe6D08b85C7B47140C8c10AF5C62678b4a;

    function setUp() public {
        vm.createSelectFork("https://eth.llamarpc.com");
        ISatoshiCore _satoshiCore = ISatoshiCore(address(new SatoshiCore(owner, owner, owner, owner)));
        oracle = new PriceFeedCurveLPOracle(pool, 18, _satoshiCore);
    }

    function test_CurvefetchPrice() public {
        uint256 price = oracle.fetchPrice();
        assertEq(ICurvePool(oracle.source()).get_virtual_price(), price);
    }

    function test_CurvefetchPriceUnsafe() public {
        (uint256 price,) = oracle.fetchPriceUnsafe();
        assertEq(ICurvePool(oracle.source()).get_virtual_price(), price);
    }
}
