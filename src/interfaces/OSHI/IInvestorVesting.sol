// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IInvestorVesting {
    function start() external view returns (uint256);
    function duration() external pure returns (uint256);
    function end() external view returns (uint256);
    function releasable() external view returns (uint256);
    function releasableAfterM6() external view returns (uint256);
    function released() external view returns (uint256);
    function releasedAtM4() external view returns (uint256);
    function releasedAtM6() external view returns (uint256);
    function unreleased() external view returns (uint256);
    function unreleasedAtM4() external view returns (uint256);
    function unreleasedAtM6() external view returns (uint256);
    function vestedAmount(uint64 timestamp) external view returns (uint256);
    function token() external view returns (IERC20);
    function owner() external view returns (address);
    function transferOwnership(address newOwner) external;
    function release() external;
    function releaseAfterM6() external;
    function releaseAtM4() external;
}
