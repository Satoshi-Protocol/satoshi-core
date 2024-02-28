// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface IVault {
    function transferAllocatedTokens(address, address, uint256) external view returns (address);
}