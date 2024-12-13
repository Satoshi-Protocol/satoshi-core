// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";

interface ICDPVault {
    event StrategyAddrSet(address strategyAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);
    event WhitelistSet(address account, bool status);

    function setStrategyAddr(address _strategyAddr) external;
    function executeStrategy(bytes calldata data) external;
    function exitStrategy(bytes calldata data) external returns (uint256);
    function initialize(bytes calldata data) external;
    function constructExecuteStrategyData(uint256 amount) external pure returns (bytes memory);
    function constructExitStrategyData(uint256 amount) external pure returns (bytes memory);
}
