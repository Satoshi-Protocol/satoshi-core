// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xFF83Dc0c17A756500f23f725B29DA118dA376A5D;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x0C68C9d4987Eedc9F5f775FC789D872ead7c94fE;
address constant OSHI_TOKEN_ADDRESS = 0x89A26F8dBa54543a3a9AB8eEc7f2c8fded37Cf8e;
address constant REWARD_MANAGER_ADDRESS = 0x95acBFa02dB2Eb305ddCB59B3A9528eE330B0f4b;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x20979D13ed43295764063F7076f4182fdC34442d;
address constant COLLATERAL_ADDRESS = 0x5CFd971FC0A5ba61D79AeC6B37724307867FEED7;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 0; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
