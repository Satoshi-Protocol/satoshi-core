// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ICommunityIssuance} from "./ICommunityIssuance.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISatoshiLPToken is IERC20 {
    event LPTokenDeposited(address lptoken, address receiver, uint256 amount);
    event LPTokenWithdrawn(address lptoken, address receiver, uint256 amount);
    event RewardClaimed(address receiver, uint256 amount);

    function setRewardRate(uint256 _rewardRate) external;
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function claimReward() external returns (uint256);
    function claimableReward(address account) external view returns (uint256);
    function communityIssuance() external view returns (ICommunityIssuance);
    function rewardIntegral() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function lastUpdate() external view returns (uint32);
    function rewardIntegralFor(address account) external view returns (uint256);
}
