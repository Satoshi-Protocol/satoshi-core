// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xb59727aBE498fb7d163028802d8573dd188251b1;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xbD9C464595904a4DCD0F0B21be18537EB69Cb6c5;
address constant OSHI_TOKEN_ADDRESS = 0x2546D04e0fFD9776755dB383f093A5D0851B9e4E;
address constant REWARD_MANAGER_ADDRESS = 0xeFab5Fa66498982ECb4df226349482a18Af0885b;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x2c52Ba7d23bc837aB949616bb0a46d6b02c3E201;
address constant COLLATERAL_ADDRESS = 0x23a62E7A0b8541b6C217A5a1E750CDb01E954807;

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
