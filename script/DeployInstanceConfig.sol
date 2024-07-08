// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0xB72421C649B00949d5D20A876aFa014f9A6707AA;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xBEDe6eb6234c0428150F1E55Bd3FCa7fa2dEc7C6;
address constant OSHI_TOKEN_ADDRESS = 0xa2Dd9C51eF298c8A5321475B365bc9C6BD799abA;
address constant REWARD_MANAGER_ADDRESS = 0x9f5bCD3529d3B610BeA2b4E5FE273D1Fc059B8F6;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xD97E656BcD9c4f19cDdF70D7EeF413dE1Fc01211;
address constant COLLATERAL_ADDRESS = 0x176409dc15e4C80cC3b9b84EF7599375E58eAcd0;

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
