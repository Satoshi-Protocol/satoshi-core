// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant FACTORY_ADDRESS = 0xB5dE77ab88551aA1ed3EE293f740C17Bc40de454;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x07B3f02441Fdd20673b2F02c820bB6CEeB09628E;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xfA3646d4578e97ca950b99010dbD701e6AFf6836;
address constant COLLATERAL_ADDRESS = 0x51abb19F1ebc7B64040aFd0ef3C789d75C8707e0;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 450; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)
