// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant FACTORY_ADDRESS = 0xeD542cBE7E19ebC80D4592e2dAb4A2ddA757cCd3;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xa5bbcC8D0cFC12E91b042ca5cF8C92c16Fa24927;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xEA22DfEB2cDFD3b21575c8877A635474f39f8F3b;
address constant COLLATERAL_ADDRESS = 0x51abb19F1ebc7B64040aFd0ef3C789d75C8707e0;
address constant REWARD_MANAGER_ADDRESS = 0x0000000000000000000000000000000000000000;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 450; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)
uint128 constant REWARD_RATE = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
