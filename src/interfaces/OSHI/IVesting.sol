// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IVesting {
    function start() external view returns (uint256);
    function duration() external pure returns (uint256);
    function end() external view returns (uint256);
    function released() external view returns (uint256);
    function releasable() external view returns (uint256);
    function release() external;
    function vestedAmount(uint64 timestamp) external view returns (uint256);
    function token() external view returns (IERC20);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
}
