// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IPool} from "../interfaces/dependencies/vault/IPool.sol";
import {VaultCore} from "./VaultCore.sol";
import {DataTypes} from "../../src/dependencies/vault/DataTypes.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract AvalonVault is VaultCore {
    using SafeERC20 for IERC20;

    enum Option {
        SUPPLY,
        WITHDRAW
    }

    // token -> strategy
    mapping(address => address) public strategy;

    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address vaultManager_) = _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        vaultManager = vaultManager_;
    }

    function executeStrategy(bytes calldata data) external override onlyManager {
        Option option = _decodeExecuteData(data);

        if (option == Option.SUPPLY) {
            _supply(data[32:]);
        } else if (option == Option.WITHDRAW) {
            _withdraw(data[32:]);
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

    function constructSupplyData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.SUPPLY, token, amount);
    }

    function constructWithdrawData(address token, uint256 amount) external pure returns (bytes memory) {
        return abi.encode(Option.WITHDRAW, token, amount);
    }

    function constructExitByTroveManagerData(address token, uint256 amount)
        external
        view
        override
        returns (bytes memory)
    {
        uint256 positionAmount = getPosition(token);
        // check the amount is not greater than the position amount, prevent revert
        if (positionAmount < amount) {
            amount = positionAmount;
        }
        return abi.encode(Option.WITHDRAW, token, amount);
    }

    function decodeTokenAddress(bytes calldata data) external pure override returns (address) {
        address token;
        Option option = _decodeExecuteData(data);
        if (option == Option.SUPPLY) {
            (token,) = _decodeSupplyData(data[32:]);
        } else if (option == Option.WITHDRAW) {
            (token,) = _decodeWithdrawData(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }

        return token;
    }

    function getPosition(address token) public view override returns (uint256) {
        DataTypes.ReserveData memory data = IPool(strategy[token]).getReserveData(token);
        return IERC20(data.aTokenAddress).balanceOf(address(this));
    }

    // --- Internal functions ---

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address) {
        return abi.decode(data, (ISatoshiCore, address));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (Option) {
        return abi.decode(data, (Option));
    }

    function _decodeSupplyData(bytes memory data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _decodeWithdrawData(bytes memory data) internal pure returns (address, uint256) {
        return abi.decode(data, (address, uint256));
    }

    function _supply(bytes memory data) internal {
        (address token, uint256 amount) = _decodeSupplyData(data);
        IERC20(token).safeTransferFrom(vaultManager, address(this), amount);
        address strategyAddr = strategy[token];
        IERC20(token).forceApprove(strategyAddr, amount);
        IPool(strategyAddr).supply(token, amount, address(this), 0);
    }

    function _withdraw(bytes memory data) internal {
        (address token, uint256 amount) = _decodeWithdrawData(data);
        address strategyAddr = strategy[token];
        IPool(strategyAddr).withdraw(token, amount, vaultManager);
    }
}
