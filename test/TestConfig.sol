// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RoundData} from "../src/mocks/OracleMock.sol";
import {DeploymentParams} from "../src/core/Factory.sol";

/* Deploy setup */
address constant DEPLOYER = 0x1234567890123456789012345678901234567890;
address constant OWNER = 0x1111111111111111111111111111111111111111;
address constant GUARDIAN = 0x2222222222222222222222222222222222222222;
address constant FEE_RECEIVER = 0x3333333333333333333333333333333333333333;
address constant REWARD_MANAGER = 0x4444444444444444444444444444444444444444;
address constant VAULT = 0x5555555555555555555555555555555555555555;
string constant DEBT_TOKEN_NAME = "TEST_TOKEN_NAME";
string constant DEBT_TOKEN_SYMBOL = "TEST_TOKEN_SYMBOL";
uint256 constant GAS_COMPENSATION = 5e18;
uint256 constant BO_MIN_NET_DEBT = 45e18;

/* Deploy instance */
// DeploymentParams
uint256 constant MINUTE_DECAY_FACTOR = 999037758833783500; //  (half life of 12 hours)
uint256 constant REDEMPTION_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_REDEMPTION_FEE = 1e18; //  (100%)
uint256 constant BORROWING_FEE_FLOOR = 1e18 / 1000 * 5; //  (0.5%)
uint256 constant MAX_BORROWING_FEE = 1e18 / 100 * 5; //  (5%)
uint256 constant INTEREST_RATE_IN_BPS = 500; //  (5%)
uint256 constant MAX_DEBT = 1e18 * 1000000000; //  (1 billion)
uint256 constant MCR = 11 * 1e17;
uint128 constant REWARD_RATE = 126839167935058336; //  (20_000_000e18 / (5 * 31536000))
uint256 constant OSHI_ALLOCATION = 20 * _1_MILLION;
uint32 constant SP_CLAIM_START_TIME = 0;
uint32 constant TM_CLAIM_START_TIME = 0;

/* Constants */
uint256 constant LIQUIDATION_FEE = 200; //  (0.5%)
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant REWARD_MANAGER_GAIN = 975; //  (97.5%)
uint256 constant REWARD_MANAGER_PRECISION = 1000;

abstract contract TestConfig {
    uint8 internal constant ORACLE_MOCK_DECIMALS = 8;
    uint256 internal constant ORACLE_MOCK_VERSION = 1;

    DeploymentParams internal deploymentParams = DeploymentParams({
        minuteDecayFactor: MINUTE_DECAY_FACTOR,
        redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
        maxRedemptionFee: MAX_REDEMPTION_FEE,
        borrowingFeeFloor: BORROWING_FEE_FLOOR,
        maxBorrowingFee: MAX_BORROWING_FEE,
        interestRateInBps: INTEREST_RATE_IN_BPS,
        maxDebt: MAX_DEBT,
        MCR: MCR,
        rewardRate: REWARD_RATE,
        OSHIAllocation: OSHI_ALLOCATION,
        claimStartTime: TM_CLAIM_START_TIME
    });
}
