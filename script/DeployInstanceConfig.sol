// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x28d2fAdEE77f3B89661a5fD30B4d820B3baf05b2;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xB7DeeFa4e0f8bEa85421f0acee38a33E8C2E00d5;
address constant OSHI_TOKEN_ADDRESS = 0xF0225d5b6E5d3987499B52B3A95A3afB3D8D1263;
address constant REWARD_MANAGER_ADDRESS = 0xfc8ab0e486F17c78Eaf59A416168d0F89D9373eD;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0x40918B4649a618eEE47f62Be7Fb6ce5b9906da9A;
address constant COLLATERAL_ADDRESS = 0x23a62E7A0b8541b6C217A5a1E750CDb01E954807;

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
