// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x1d015247bD90b92727A66Eae18608E34b8693487;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x946e41763FCF05E645e0DCBc055c46061CF9c0b8;
address constant OSHI_TOKEN_ADDRESS = 0xF780F2C7971af009f00B912510F58FED7F4eAcf3;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x8ef3436fc93d6289E47a0A0562193038C0b4Dbf8;
address constant COLLATERAL_ADDRESS = 0xe454776c60E63F987f287b97172884E4B1FB890a;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 450; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 10 * _1_MILLION; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
