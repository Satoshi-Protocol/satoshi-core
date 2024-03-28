// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xC3144471bD68ACC2ab108819CFDf8548543176A5;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x3dD4f09cef28842cE9958571F4Aab9dc605a2fF4;
address constant OSHI_TOKEN_ADDRESS = 0xf1067e81AdF2c2F9cAA8edbB75b6ccDfAD4dcBF1;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x688a62Cb8CE36907B6f3B0C5FEa62fD41F1D501d;
address constant COLLATERAL_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 450; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 20 * _1_MILLION; //  20,000,000 OSHI (20% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
