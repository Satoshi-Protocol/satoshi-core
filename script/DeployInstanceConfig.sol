// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xCae5eA815EfDF71978855F9df66Ce012a16b8bf7;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xB8954C4e7EBCEEF6F00e3003d5B376A78BF7321F;
address constant OSHI_TOKEN_ADDRESS = 0x4324026b1B74b24c1844a102a687466B9ac15eBa;
address constant REWARD_MANAGER_ADDRESS = 0x269EeCEa5E9304fA1bc9361461798134e9AE4A60;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xc6c9132bAa3a41Ce9e79538522a3194563ce5Bd6;
address constant COLLATERAL_ADDRESS = 0x2868d708e442A6a940670d26100036d426F1e16b;

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
