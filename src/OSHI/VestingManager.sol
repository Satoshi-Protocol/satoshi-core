// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Vesting} from "./Vesting.sol";
import {InvestorVesting} from "./InvestorVesting.sol";
import {IVestingManager, VestingType} from "../interfaces/OSHI/IVestingManager.sol";

/**
 * @title Vesting Manager Contract
 *        Deploy the vesting contracts for the team, advisors and investors
 */
contract VestingManager is SatoshiOwnable, IVestingManager {
    using SafeERC20 for IERC20;

    IERC20 public immutable token; // OSHI token
    uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
    uint256 internal allocatedToTeam = 15 * _1_MILLION; // 15 million
    uint256 internal allocatedToAdvisor = 2 * _1_MILLION; // 2 million

    constructor(ISatoshiCore _satoshiCore, address _token) {
        __SatoshiOwnable_init(_satoshiCore);
        token = IERC20(_token);
    }

    /**
     * @dev Deploy the vesting contract for the team and advisors
     */
    function deployVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp, VestingType _type)
        external
        onlyOwner
        returns (address)
    {
        require(_beneficiary != address(0), "VestingManager: beneficiary is the zero address");
        require(_amount != 0, "VestingManager: amount is 0");
        require(_type == VestingType.TEAM || _type == VestingType.ADVISOR, "VestingManager: invalid vesting type");
        if (_type == VestingType.TEAM) {
            require(_amount <= allocatedToTeam, "VestingManager: amount exceeds");
            allocatedToTeam -= _amount;
        } else if (_type == VestingType.ADVISOR) {
            require(_amount <= allocatedToAdvisor, "VestingManager: amount exceeds");
            allocatedToAdvisor -= _amount;
        }

        Vesting vesting = new Vesting(address(token), _amount, _beneficiary, _startTimestamp);
        token.safeTransfer(address(vesting), _amount);
        emit VestingDeployed(address(vesting), _amount, _startTimestamp);

        return address(vesting);
    }

    /**
     * @dev Deploy the vesting contract for the investors
     */
    function deployInvestorVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp)
        external
        onlyOwner
        returns (address)
    {
        require(_beneficiary != address(0), "VestingManager: beneficiary is the zero address");
        require(_amount != 0, "VestingManager: amount is 0");
        require(_amount <= 10 * _1_MILLION, "VestingManager: amount should less than 10 million");

        InvestorVesting investorVesting = new InvestorVesting(address(token), _amount, _beneficiary, _startTimestamp);
        token.safeTransfer(address(investorVesting), _amount);
        emit VestingDeployed(address(investorVesting), _amount, _startTimestamp);

        return address(investorVesting);
    }
}
