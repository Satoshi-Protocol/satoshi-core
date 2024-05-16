// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xd4B1d66ab46097881B3CcfAA972F9E1Af0902c98;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x8ef3436fc93d6289E47a0A0562193038C0b4Dbf8;
address constant OSHI_TOKEN_ADDRESS = 0x80955FA56Be986D1419326A85ed1Db3F5AE30587;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xC0c376973F4440A740dc6b41DCfFf35511506605;
address constant COLLATERAL_ADDRESS = 0x2DcA0825F0d5E900c1522a9A2362237BbaAecbb4;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 650; //  (6.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 10 * _1_MILLION; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
