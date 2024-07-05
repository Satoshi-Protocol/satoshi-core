// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {_1_MILLION} from "./DeploySetupConfig.sol";

address constant FACTORY_ADDRESS = 0x1475571080Cb41f56BD1597b15CE61ce8FA7ac44;
address constant PRICE_FEED_AGGREGATOR_ADDRESS = 0xc6268010A409E97D4847e413105C5E2a226ffD59;
address constant OSHI_TOKEN_ADDRESS = 0xBAE6744672D3C1ce9f26E994477C63dfd765F3DE;
address constant REWARD_MANAGER_ADDRESS = 0xA33136f3c1E1B304a2B999BBb003864bAccd999E;

//NOTE: custom `PriceFeed.sol` contract for the collateral should be deploy first
address constant PRICE_FEED_ADDRESS = 0xc44Eb98f4F1D905e23CC9a7d05A9d5B94be1D32f;
address constant COLLATERAL_ADDRESS = 0x4200000000000000000000000000000000000006;

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
