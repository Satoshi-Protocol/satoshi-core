// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x2fbFD4b610e397229501b9BF1a986eba737273D9;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x1aa0a2DEB5c8215E4C644699165C9ebE38D94ca7;
address constant OSHI_TOKEN_ADDRESS = 0x8043335FDA6475b9BFa2F0aE0D49331950844bE1;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xE58550377c1BdBCd524F3E677340589C09B0FEB5;
address constant COLLATERAL_ADDRESS = 0x2DcA0825F0d5E900c1522a9A2362237BbaAecbb4;

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
