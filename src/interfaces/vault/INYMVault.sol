// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";

interface INYMVault {
    event StrategyAddrSet(address strategyAddr);
    event NYMAddrSet(address nymAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToNYM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);
    event WhitelistSet(address account, bool status);
    event TokenIdAdded(uint256 tokenId);
    event TokenIdRemoved(uint256 tokenId);
    event createDeposit(uint256 tokenId);
    event FeeCollected(uint256 tokenId, uint256 amount0, uint256 amount1);

    error DebtTokenBalanceUnexpectedChange(uint256 expect, uint256 actual);
    error InvalidOption(uint256 option);
    error ZeroLiquidity();
    error InvalidLiquidity(uint128 liquidity);
    error Unauthorized();

    function setStrategyAddr(address _strategyAddr) external;
    function setNYMAddr(address _nymAddr) external;
    function transferTokenToNYM(uint256 amount) external;
    function executeStrategy(bytes calldata data) external;
    function exitStrategy(bytes calldata data) external returns (uint256);
    function executeCall(address dest, bytes calldata data) external;
    function initialize(bytes calldata data) external;
    function constructExecuteStrategyData(uint256 amount) external pure returns (bytes memory);
    function constructExitStrategyData(uint256 amount) external pure returns (bytes memory);
}
