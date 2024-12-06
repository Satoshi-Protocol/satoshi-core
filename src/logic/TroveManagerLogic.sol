// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ITroveManager, Trove} from "../interfaces/core/ITroveManager.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

library TroveManagerLogic {
    function claimableReward(address account) external view returns (uint256) {
        ITroveManager troveManagerBeaconProxy = ITroveManager(address(this));

        // previously calculated rewards
        uint256 amount = troveManagerBeaconProxy.getStoredPendingReward(account);

        // pending active debt rewards
        uint256 duration = block.timestamp - troveManagerBeaconProxy.lastUpdate();
        uint256 integral = troveManagerBeaconProxy.rewardIntegral();
        if (duration > 0) {
            uint256 supply = troveManagerBeaconProxy.totalActiveDebt();
            if (supply > 0) {
                uint256 releasedToken = duration * troveManagerBeaconProxy.rewardRate();
                uint256 allocatedToken =
                    troveManagerBeaconProxy.communityIssuance().allocated(address(troveManagerBeaconProxy));
                // check the allocated token in community issuance
                if (releasedToken > allocatedToken) {
                    releasedToken = allocatedToken;
                }
                integral += releasedToken * 1e18 / supply;
            }
        }
        uint256 integralFor = troveManagerBeaconProxy.rewardIntegralFor(account);

        if (integral > integralFor) {
            (uint256 debt,,,,,) = troveManagerBeaconProxy.troves(account);
            amount += (debt * (integral - integralFor)) / 1e18;
        }

        return amount;
    }

    function collateralRefill(uint256 _amount, uint256 boundary, uint256 remainColl, uint256 target) external {
        ITroveManager troveManagerBeaconProxy = ITroveManager(address(this));

        // remain collateral is not enough, must refill
        if (_amount > remainColl) {
            troveManagerBeaconProxy.vaultManager().exitStrategyByTroveManager(_amount - remainColl);
            // refill to target
            uint256 refillAmount = SatoshiMath._min(target, troveManagerBeaconProxy.collateralOutput());
            if (refillAmount != 0) troveManagerBeaconProxy.vaultManager().exitStrategyByTroveManager(refillAmount);
        } else if (remainColl - _amount < boundary) {
            uint256 refillAmount = _amount + target - remainColl;
            troveManagerBeaconProxy.vaultManager().exitStrategyByTroveManager(refillAmount);
        }
    }

    function calculateInterestIndex() external view returns (uint256 currentInterestIndex, uint256 interestFactor) {
        ITroveManager troveManagerBeaconProxy = ITroveManager(address(this));

        uint256 lastIndexUpdateCached = troveManagerBeaconProxy.lastActiveIndexUpdate();
        // Short circuit if we updated in the current block
        if (lastIndexUpdateCached == block.timestamp) return (troveManagerBeaconProxy.activeInterestIndex(), 0);
        uint256 currentInterest = troveManagerBeaconProxy.interestRate();
        currentInterestIndex = troveManagerBeaconProxy.activeInterestIndex(); // we need to return this if it's already up to date
        if (currentInterest > 0) {
            /*
             * Calculate the interest accumulated and the new index:
             * We compound the index and increase the debt accordingly
             */
            uint256 deltaT = block.timestamp - lastIndexUpdateCached;
            interestFactor = deltaT * currentInterest;
            currentInterestIndex = currentInterestIndex
                + Math.mulDiv(currentInterestIndex, interestFactor, troveManagerBeaconProxy.INTEREST_PRECISION());
        }
    }
}
