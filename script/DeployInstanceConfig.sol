// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

address constant COLLATERAL_ADDRESS = address(0);
address constant PRICE_FEED_ADDRESS = address(0);
address constant CUSTOM_TROVE_MANAGER_IMPL = address(0);
address constant CUSTOM_SORTED_TROVES_IMPL = address(0);

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18; //  (100%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 250; //  (2.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)
