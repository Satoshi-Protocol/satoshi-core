// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ITroveManager} from "../src/interfaces/core/ITroveManager.sol";
import {IMultiCollateralHintHelpers} from "../src/helpers/interfaces/IMultiCollateralHintHelpers.sol";
import {ISortedTroves} from "../src/interfaces/core/ISortedTroves.sol";
import {ISatoshiPeriphery} from "../src/helpers/interfaces/ISatoshiPeriphery.sol";
import {DeploymentParams} from "../src/interfaces/core/IFactory.sol";
import {TroveHelper} from "../src/helpers/TroveHelper.sol";
import {
    MINUTE_DECAY_FACTOR,
    REDEMPTION_FEE_FLOOR,
    MAX_REDEMPTION_FEE,
    BORROWING_FEE_FLOOR,
    MAX_BORROWING_FEE,
    INTEREST_RATE_IN_BPS,
    MAX_DEBT,
    MCR,
    REWARD_RATE,
    TM_ALLOCATION,
    TM_CLAIM_START_TIME
} from "../script/DeployInstanceConfig.sol";

contract TMSetParamtersScript is Script {
    ITroveManager troveManagerBTC = ITroveManager(0x0598Ef47508Ec11a503670Ac3B642AAE8EAEdEFA);
    ITroveManager troveManagerwstBTC = ITroveManager(0xa794a7Fd668FE378E095849caafA8C8dC7E84780);
    DeploymentParams internal params;
    uint256 internal OWNER_PRIVATE_KEY;

    function setUp() public {
        OWNER_PRIVATE_KEY = uint256(vm.envBytes32("OWNER_PRIVATE_KEY"));
    }

    function run() public {
        vm.startBroadcast(OWNER_PRIVATE_KEY);
        params = DeploymentParams({
            minuteDecayFactor: MINUTE_DECAY_FACTOR,
            redemptionFeeFloor: REDEMPTION_FEE_FLOOR,
            maxRedemptionFee: MAX_REDEMPTION_FEE,
            borrowingFeeFloor: BORROWING_FEE_FLOOR,
            maxBorrowingFee: MAX_BORROWING_FEE,
            interestRateInBps: 0,
            maxDebt: MAX_DEBT,
            MCR: MCR,
            rewardRate: REWARD_RATE,
            OSHIAllocation: TM_ALLOCATION,
            claimStartTime: TM_CLAIM_START_TIME
        });
        troveManagerBTC.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR,
            params.rewardRate,
            params.claimStartTime
        );
        troveManagerwstBTC.setParameters(
            params.minuteDecayFactor,
            params.redemptionFeeFloor,
            params.maxRedemptionFee,
            params.borrowingFeeFloor,
            params.maxBorrowingFee,
            params.interestRateInBps,
            params.maxDebt,
            params.MCR,
            params.rewardRate,
            params.claimStartTime
        );
        vm.stopBroadcast();
    }
}
