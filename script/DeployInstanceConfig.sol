// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x6Aa76643c39cd01E2B9cEfEC89729309fb1397e2;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0x395cfeebbE370dE24F4C8Ddb14CdC8bE76762b7e;
address constant OSHI_TOKEN_ADDRESS = 0x0c29bbe9c9cf86F5eDEd5060d4525894d88d128b;
address constant REWARD_MANAGER_ADDRESS = 0x63E51aD72af5B244B60638c86445EA39466e8DB1;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x896a6a8937C38A0f89BfD8Db8B071BE4D4cdfB83;
address constant COLLATERAL_ADDRESS = 0x4200000000000000000000000000000000000006;

uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 0; //  (4.5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 12 * 1e17; //  (110%)

// OSHI token configuration
uint256 constant TM_ALLOCATION = 0; //  10,000,000 OSHI (10% of total supply)
uint128 constant REWARD_RATE = 0; // 126839167935058336 (20_000_000e18 / (5 * 31536000))

//TODO: Replace with the actual timestamp
uint32 constant TM_CLAIM_START_TIME = 4294967295; // max uint32
