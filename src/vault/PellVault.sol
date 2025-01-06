// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IStrategyManager} from "../interfaces/dependencies/vault/IStrategyManager.sol";
import {IDelegationManager} from "../interfaces/dependencies/vault/IDelegationManager.sol";
import {IStrategy} from "../interfaces/dependencies/vault/IStrategy.sol";
import {VaultCore} from "./VaultCore.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PellVault
 * @notice A vault contract that manages deposits and withdrawals through Pell's restaking strategies
 * @dev Inherits from VaultCore and implements strategy management functionality
 */
contract PellVault is VaultCore {
    using SafeERC20 for IERC20;

    /**
     * @notice Available operations for strategy execution
     * @param Deposit Deposit tokens into the strategy
     * @param QueueWithdraw Queue a withdrawal request
     * @param CompleteQueueWithdraw Complete a queued withdrawal
     */
    enum Option {
        Deposit,
        QueueWithdraw,
        CompleteQueueWithdraw
    }

    address public strategyManager;
    address public delegationManager;
    // token -> strategy
    mapping(address => address) public strategy;

    IDelegationManager.Withdrawal[] public withdrawalQueue;

    /**
     * @notice Initializes the vault with core components
     * @param data Encoded initialization parameters (satoshiCore, vaultManager, strategyManager, delegationManager)
     */
    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address vaultManager_, address strategyManager_, address delegationManager_) =
            _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        vaultManager = vaultManager_;
        strategyManager = strategyManager_;
        delegationManager = delegationManager_;

        emit StrategyManagerSet(strategyManager_);
        emit DelegationManagerSet(delegationManager_);
        emit VaultManagerSet(vaultManager_);
    }

    /**
     * @notice Executes a strategy operation (deposit, queue withdrawal, or complete withdrawal)
     * @param data Encoded operation parameters
     * @dev Can only be called by the vault manager
     */
    function executeStrategy(bytes calldata data) external override onlyManager {
        Option option = _decodeExecuteData(data);

        if (option == Option.Deposit) {
            _deposit(data[32:]);
        } else if (option == Option.QueueWithdraw) {
            _queueWithdraw(data[32:]);
        } else if (option == Option.CompleteQueueWithdraw) {
            _completeQueueWithdraw(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }
    }

    /**
     * @notice Sets the strategy address for a specific token
     * @param token The token address
     * @param strategy_ The strategy address for the token
     * @dev Can only be called by the owner
     */
    function setTokenStrategy(address token, address strategy_) external onlyOwner {
        strategy[token] = strategy_;
        emit TokenStrategySet(token, strategy_);
    }

    /**
     * @notice Updates the strategy manager address
     * @param strategyManager_ The new strategy manager address
     * @dev Can only be called by the owner
     * @dev The strategy manager is responsible for handling deposits into Pell strategies
     */
    function setStrategyManager(address strategyManager_) external onlyOwner {
        strategyManager = strategyManager_;
        emit StrategyManagerSet(strategyManager_);
    }

    /**
     * @notice Updates the delegation manager address
     * @param delegationManager_ The new delegation manager address
     * @dev Can only be called by the owner
     * @dev The delegation manager handles withdrawal queuing and completion
     */
    function setDelegationManager(address delegationManager_) external onlyOwner {
        delegationManager = delegationManager_;
        emit DelegationManagerSet(delegationManager_);
    }

    // --- View functions ---

    function constructDepositData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.Deposit, token, amount);
    }

    function constructQueueWithdrawData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.QueueWithdraw, token, amount);
    }

    function constructCompleteQueueWithdrawData(address token) external pure returns (bytes memory) {
        return abi.encode(Option.CompleteQueueWithdraw, token);
    }

    function decodeTokenAddress(bytes calldata data) external override pure returns (address) {
        address token;
        Option option = _decodeExecuteData(data);
        if (option == Option.Deposit) {
            (token,) = _decodeDepositData(data[32:]);
        } else if (option == Option.QueueWithdraw) {
            (token,) = _decodeQueueWithdrawData(data[32:]);
        } else if (option == Option.CompleteQueueWithdraw) {
            (token) = _decodeCompleteQueueWithdrawData(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }

        return token;
    }

    function getPosition(address token) external view override returns (uint256) {
        return (IStrategy(strategy[token]).userUnderlyingView(address(this)));
    }

    // --- Internal functions ---

    /**
     * @notice Deposits tokens into the Pell restaking strategy
     * @param data Encoded deposit parameters (token, amount)
     */
    function _deposit(bytes calldata data) internal {
        (address token, uint256 amount) = _decodeDepositData(data);
        IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
        IERC20(token).approve(strategyManager, amount);
        // deposit token to pell restake strategy
        IStrategyManager(strategyManager).depositIntoStrategy(IStrategy(strategy[token]), IERC20(token), amount);

        emit DepositToPellStrategy(token, strategy[token], amount);
    }

    /**
     * @notice Queues a withdrawal request
     * @param data Encoded withdrawal parameters (token, amount)
     */
    function _queueWithdraw(bytes calldata data) internal {
        (address token, uint256 amount) = _decodeQueueWithdrawData(data);
        IStrategy[] memory strategies = new IStrategy[](1);
        strategies[0] = IStrategy(strategy[token]);

        uint256[] memory shares = new uint256[](1);
        shares[0] = amount;

        IDelegationManager.QueuedWithdrawalParams[] memory queuedWithdrawal =
            new IDelegationManager.QueuedWithdrawalParams[](1);
        queuedWithdrawal[0] = IDelegationManager.QueuedWithdrawalParams({
            strategies: strategies,
            shares: shares,
            withdrawer: address(this)
        });

        uint256 nonce = IDelegationManager(delegationManager).cumulativeWithdrawalsQueued(address(this));

        IDelegationManager(delegationManager).queueWithdrawals(queuedWithdrawal);

        IDelegationManager.Withdrawal memory withdrawal = IDelegationManager.Withdrawal({
            staker: address(this),
            delegatedTo: address(0),
            withdrawer: address(this),
            nonce: nonce,
            startTimestamp: uint32(block.timestamp),
            strategies: strategies,
            shares: shares
        });

        withdrawalQueue.push(withdrawal);

        emit WithdrawQueuedOnPell(withdrawal);
    }

    /**
     * @notice Completes a queued withdrawal
     * @param data Encoded completion parameters (token)
     */
    function _completeQueueWithdraw(bytes calldata data) internal {
        _checkWithdrawalTimeAvailable(0);

        address token = _decodeCompleteQueueWithdrawData(data);

        IDelegationManager.Withdrawal[] memory withdrawals = new IDelegationManager.Withdrawal[](1);
        withdrawals[0] = withdrawalQueue[0];

        IERC20[][] memory tokens = new IERC20[][](1);
        tokens[0] = new IERC20[](1);
        tokens[0][0] = IERC20(token);
        uint256[] memory middlewareTimesIndexes = new uint256[](1);
        middlewareTimesIndexes[0] = 0;
        bool[] memory receiveAsTokens = new bool[](1);
        receiveAsTokens[0] = true;
        IDelegationManager(delegationManager).completeQueuedWithdrawals(
            withdrawals, tokens, middlewareTimesIndexes, receiveAsTokens
        );

        _removeWithdrawalQueue(0);

        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(vaultManager, balance);

        emit CompleteQueueWithdrawOnPell(withdrawals[0]);
    }

    /**
     * @notice Checks if enough time has passed for a withdrawal to be completed
     * @param index Index of the withdrawal in the queue
     * @dev Reverts if withdrawal time is not yet available
     */
    function _checkWithdrawalTimeAvailable(uint256 index) internal view {
        if (
            uint256(withdrawalQueue[index].startTimestamp) + IDelegationManager(delegationManager).minWithdrawalDelay()
                > block.timestamp
        ) {
            revert WithdrawalTimeNotAvailable();
        }
    }

    /**
     * @notice Removes a withdrawal from the queue
     * @param index Index of the withdrawal to remove
     * @dev Shifts remaining elements and pops the last element
     */
    function _removeWithdrawalQueue(uint256 index) internal {
        if (index >= withdrawalQueue.length) revert IndexOutOfRange(index);
        for (uint256 i = index; i < withdrawalQueue.length - 1; i++) {
            withdrawalQueue[i] = withdrawalQueue[i + 1];
        }
        withdrawalQueue.pop();
    }

    function _decodeInitializeData(bytes calldata data)
        internal
        pure
        returns (ISatoshiCore, address, address, address)
    {
        return abi.decode(data, (ISatoshiCore, address, address, address));
    }

    function _decodeDepositData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeQueueWithdrawData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeCompleteQueueWithdrawData(bytes calldata data) internal pure returns (address) {
        return abi.decode(data, (address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (Option) {
        return abi.decode(data, (Option));
    }
}
