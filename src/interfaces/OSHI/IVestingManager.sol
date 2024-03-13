// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";

enum VestingType {
    TEAM,
    ADVISOR,
    INVESTOR,
    RESERVE
}

interface IVestingManager is ISatoshiOwnable {
    event VestingDeployed(address indexed, uint256, uint64);

    function deployVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp, VestingType _type)
        external
        returns (address);
    function deployInvestorVesting(address _beneficiary, uint256 _amount, uint64 _startTimestamp)
        external
        returns (address);
}
