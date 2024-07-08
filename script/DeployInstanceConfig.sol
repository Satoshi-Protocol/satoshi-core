// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x234eB2615533ca52f89BBF881F890D6E8495939A;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xF70F9b7F3c3462b3730b4f51dB5356b45B01bCfF;
address constant OSHI_TOKEN_ADDRESS = 0xD7755aF987CbA1B77b4fda93cA5d03ae3C0dD5B2;
address constant REWARD_MANAGER_ADDRESS = 0xfAe7c7683675f2c9a1E8Dfc015b80C80fae765D7;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xaF6c2cFebf105fBA96E7d5e6CB2CA247c42E8029;
address constant COLLATERAL_ADDRESS = 0x9296376D54C79A8dF8C28D8d5d88a84D3e0245a0;

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
