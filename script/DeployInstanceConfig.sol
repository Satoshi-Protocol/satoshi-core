// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant FACTORY_ADDRESS = 0xDfAA53cB0Ce891485389fEBdcD547965906A8300;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xDfAA53cB0Ce891485389fEBdcD547965906A8300;
address constant PRICE_FEED_ADDRESS = 0xdAf9EF6c3d250C6e2015908f67071A0FF4D012B7;
address constant COLLATERAL_ADDRESS = 0xc556bAe1e86B2aE9c22eA5E036b07E55E7596074;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18; //  (100%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 250; //  (2.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)
