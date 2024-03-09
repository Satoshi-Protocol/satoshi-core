// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xe5aD859a3b4e7FCDf1cAE58c41115B6f3f1AF6D2;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xd7505eCe56b6318749f3DDFdD6629c9302a8fD66;
address constant OSHI_TOKEN_ADDRESS = 0x21BB93c193394C10702b69F9da682E64E01C23B8;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x477FB5860dd4804845e4fe10041C16d029b10079;
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
uint32 constant TM_CLAIM_START_TIME = 1709992800; 
