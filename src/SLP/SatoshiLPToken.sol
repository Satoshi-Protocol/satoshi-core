// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ISatoshiLPToken} from "../interfaces/core/ISatoshiLPToken.sol";

contract SatoshiLPToken is SatoshiOwnable, ERC20, ISatoshiLPToken {
    using SafeERC20 for *;

    ICommunityIssuance public communityIssuance;
    IERC20 public lpToken;

    uint256 public rewardIntegral;
    uint256 public rewardRate;
    uint32 public lastUpdate;

    mapping(address => uint256) public rewardIntegralFor;
    mapping(address => uint256) private storedPendingReward;

    uint32 public claimStartTime;

    constructor(
        ISatoshiCore _satoshiCore,
        string memory _name,
        string memory _symbol,
        IERC20 _lpToken,
        ICommunityIssuance _communityIssuance,
        uint32 _claimStartTime
    ) ERC20(_name, _symbol) {
        __SatoshiOwnable_init(_satoshiCore);
        lpToken = _lpToken;
        communityIssuance = _communityIssuance;
        lastUpdate = uint32(block.timestamp);
        claimStartTime = _claimStartTime;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        _updateRewardIntegral(totalSupply());
        rewardRate = _rewardRate;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "SatoshiLPToken: amount must be greater than 0");
        lpToken.safeTransferFrom(msg.sender, address(this), amount);
        // update reward
        uint256 balance = balanceOf(msg.sender);
        uint256 supply = totalSupply();
        _updateIntegrals(msg.sender, balance, supply);

        _mint(msg.sender, amount);

        emit LPTokenDeposited(address(lpToken), msg.sender, amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "SatoshiLPToken: amount must be greater than 0");
        uint256 balance = balanceOf(msg.sender);
        uint256 supply = totalSupply();
        require(balance >= amount, "SatoshiLPToken: insufficient balance");
        _burn(msg.sender, amount);
        lpToken.safeTransfer(msg.sender, amount);
        // update reward
        _updateIntegrals(msg.sender, balance, supply);

        emit LPTokenWithdrawn(address(lpToken), msg.sender, amount);
    }

    function claimReward() external returns (uint256) {
        require(isClaimStart(), "SatoshiLPToken: Claim not started");
        uint256 amount = _claimReward(msg.sender);
        if (amount > 0) {
            communityIssuance.transferAllocatedTokens(msg.sender, amount);
        }
        emit RewardClaimed(msg.sender, amount);
        return amount;
    }

    function _claimReward(address account) internal returns (uint256) {
        // update reward
        _updateIntegrals(account, balanceOf(account), totalSupply());
        uint256 amount = storedPendingReward[account];
        if (amount > 0) storedPendingReward[account] = 0;
        return amount;
    }

    function claimableReward(address account) external view returns (uint256) {
        // previously calculated rewards
        uint256 amount = storedPendingReward[account];
        uint256 duration = block.timestamp - lastUpdate;
        uint256 integral = rewardIntegral;
        if (duration > 0) {
            uint256 supply = totalSupply();
            if (supply > 0) {
                uint256 releasedToken = duration * rewardRate;
                uint256 allocatedToken = communityIssuance.allocated(address(this));
                // check the allocated token in community issuance
                if (releasedToken > allocatedToken) {
                    releasedToken = allocatedToken;
                }
                integral += releasedToken * 1e18 / supply;
            }
        }
        uint256 integralFor = rewardIntegralFor[account];

        if (integral > integralFor) {
            amount += (balanceOf(account) * (integral - integralFor)) / 1e18;
        }

        return amount;
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        uint256 supply = totalSupply();
        uint256 fromBalance = balanceOf(from);
        uint256 toBalance = balanceOf(to);
        super._transfer(from, to, amount);
        _updateIntegrals(from, fromBalance, supply);
        _updateIntegrals(to, toBalance, supply);
    }

    function _updateIntegrals(address account, uint256 balance, uint256 supply) internal {
        uint256 integral = _updateRewardIntegral(supply);
        _updateIntegralForAccount(account, balance, integral);
    }

    function _updateIntegralForAccount(address account, uint256 balance, uint256 currentIntegral) internal {
        uint256 integralFor = rewardIntegralFor[account];

        if (currentIntegral > integralFor) {
            storedPendingReward[account] += (balance * (currentIntegral - integralFor)) / 1e18;
            rewardIntegralFor[account] = currentIntegral;
        }
    }

    function _updateRewardIntegral(uint256 supply) internal returns (uint256) {
        require(lastUpdate <= block.timestamp, "SLP: Invalid last update");
        uint256 integral = rewardIntegral; // global integral
        uint256 duration = block.timestamp - lastUpdate;
        integral = _computeIntegral(duration, supply);

        return integral;
    }

    function _computeIntegral(uint256 duration, uint256 supply) internal returns (uint256) {
        uint256 integral = rewardIntegral;
        if (duration > 0) {
            lastUpdate = uint32(block.timestamp);
            if (supply > 0) {
                uint256 releasedToken = duration * rewardRate;
                uint256 allocatedToken = communityIssuance.allocated(address(this));
                // check the allocated token in community issuance
                if (releasedToken > allocatedToken) {
                    releasedToken = allocatedToken;
                }
                communityIssuance.collectAllocatedTokens(releasedToken);
                integral += releasedToken * 1e18 / supply;
                rewardIntegral = integral;
            }
        }
        return integral;
    }

    // set the time when the OSHI claim starts
    function setClaimStartTime(uint32 _claimStartTime) external onlyOwner {
        claimStartTime = _claimStartTime;
    }

    // check the start time
    function isClaimStart() public view returns (bool) {
        return claimStartTime <= uint32(block.timestamp);
    }
}
