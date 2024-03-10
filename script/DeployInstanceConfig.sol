// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x61C3ee94413120A8cE04dF89715A2B23E515C29B;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xdD3bcDF8dd3f70fe2133a0Fe718ABe0B287De334;
address constant OSHI_TOKEN_ADDRESS = 0xb8B616a6C15B6F6E6961804C08DBbd21727bb054;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x73934242C487e9b6B9FfBca700CE31F0FD205931;
address constant COLLATERAL_ADDRESS = 0x51abb19F1ebc7B64040aFd0ef3C789d75C8707e0;

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
uint128 constant REWARD_RATE = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))
uint32 constant TM_CLAIM_START_TIME = 1710079200; 
