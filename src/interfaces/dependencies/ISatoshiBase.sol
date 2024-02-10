// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ISatoshiBase {
    function DECIMAL_PRECISION() external view returns (uint256);

    function CCR() external view returns (uint256);

    function PERCENT_DIVISOR() external view returns (uint256);

    function DEBT_GAS_COMPENSATION() external view returns (uint256);
}
