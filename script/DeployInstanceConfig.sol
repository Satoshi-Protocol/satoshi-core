// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x87d15B1E5C06De05F53905A35b23D3dF0F1b9024;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x6DFD78C7d229358e83a041dd88b656A4622b523B;
address constant OSHI_TOKEN_ADDRESS = 0xE18c8256C012a94c3191c753eF6f6E9a1DB5B9f8;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xC18a497E74Ba0093CbA2D1c7268E340d5B48dDCA;
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
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 1710244800;
