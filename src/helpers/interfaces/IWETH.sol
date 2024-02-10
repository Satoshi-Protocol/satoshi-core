// SPDX-License-Identifier: MIT
// solhint-disable-next-line
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title WETH interface
 * @author Term Structure Labs
 * @notice Interface for WETH contract
 */
interface IWETH is IERC20 {
    /// @notice Deposit ETH to get WETH
    function deposit() external payable;

    /// @notice Withdraw WETH to get ETH
    function withdraw(uint256) external;
}
