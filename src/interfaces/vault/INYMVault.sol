// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {IDelegationManager} from "../dependencies/vault/IDelegationManager.sol";

interface INYMVault {
    event StrategyAddrSet(address strategyAddr);
    event NYMAddrSet(address nymAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToNYM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);
    event WhitelistSet(address account, bool status);
    event TokenIdAdded(uint256 tokenId);
    event TokenIdRemoved(uint256 tokenId);
    event CreateDeposit(uint256 tokenId);
    event FeeCollected(uint256 tokenId, uint256 amount0, uint256 amount1);
    event StrategyManagerSet(address strategyManager);
    event DelegationManagerSet(address delegationManager);
    event VaultManagerSet(address vaultManager);
    event TokenStrategySet(address token, address strategy);
    event DepositToPellStrategy(address token, address strategy, uint256 amount);
    event WithdrawQueuedOnPell(IDelegationManager.Withdrawal);
    event CompleteQueueWithdrawOnPell(IDelegationManager.Withdrawal);

    error DebtTokenBalanceUnexpectedChange(uint256 expect, uint256 actual);
    error InvalidOption(uint256 option);
    error ZeroLiquidity();
    error InvalidLiquidity(uint128 liquidity);
    error Unauthorized();
    error WithdrawalTimeNotAvailable();
    error IndexOutOfRange(uint256 index);

    function setNYMAddr(address _nymAddr) external;
    function executeStrategy(bytes calldata data) external;
    function executeCall(address dest, bytes calldata data) external;
    function initialize(bytes calldata data) external;
    function tokenAmount(address token) external view returns (uint256);
    function decodeTokenAddress(bytes calldata data) external pure returns (address);
}
