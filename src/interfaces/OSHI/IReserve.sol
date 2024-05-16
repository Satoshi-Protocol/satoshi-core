// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IReserve {
    function start() external view returns (uint256);
    function duration() external pure returns (uint256);
    function released() external view returns (uint256);
    function totalAmount() external view returns (uint256);
    function eachPeriodReleasedAmount() external view returns (uint256);
    function releasable() external view returns (uint256);
    function release() external;
    function token() external view returns (IERC20);
    function owner() external view returns (address);
}
