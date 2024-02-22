// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant FACTORY_ADDRESS = 0xCb65baE52c04a7230ba820fD47B8425E3F4F7F09;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xA78Be30f80Db4741A841B135B0FFE5AdE5c850A8;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xf26C211964ef9E804744DD73b6582496c8AbFDBc;
address constant COLLATERAL_ADDRESS = 0x51abb19F1ebc7B64040aFd0ef3C789d75C8707e0;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 450; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)
