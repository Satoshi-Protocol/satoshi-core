// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";

interface INYMVault {
    event StrategyAddrSet(address strategyAddr);
    event NYMAddrSet(address nymAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToNYM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);

    function setStrategyAddr(address _strategyAddr) external;
    function setNYMAddr(address _nymAddr) external;
    function transferTokenToNYM(uint256 amount) external;
    function executeStrategy(bytes calldata data) external;
    function exitStrategy(bytes calldata data) external returns (uint256);
    function initialize(bytes calldata data) external;
    function constructExecuteStrategyData(uint256 amount) external pure returns (bytes memory);
    function constructExitStrategyData(uint256 amount) external pure returns (bytes memory);
}
