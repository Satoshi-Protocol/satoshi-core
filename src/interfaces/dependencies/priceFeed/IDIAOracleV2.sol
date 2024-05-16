// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IDIAOracleV2 {
    function getValue(string memory) external returns (uint128, uint128);
}
