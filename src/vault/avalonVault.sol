// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IPool} from "../interfaces/dependencies/vault/IPool.sol";
import {DataTypes} from '../dependencies/vault/DataTypes.sol';

import {CDPVaultCore} from "./CDPVaultCore.sol";

contract AvalonVault is CDPVaultCore {
    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address tokenAddress_, address vaultManager_) = _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        TOKEN_ADDRESS = tokenAddress_;
        vaultManager = vaultManager_;
    }

    modifier onlyVaultManager() {
        require(msg.sender == vaultManager, "Only vault manager");
        _;
    }

    function executeStrategy(bytes calldata data) external override onlyVaultManager {
        uint256 amount = _decodeExecuteData(data);
        IERC20(TOKEN_ADDRESS).approve(strategyAddr, amount);
        // deposit token to lending
        IPool(strategyAddr).supply(TOKEN_ADDRESS, amount, address(this), 0);
    }

    function exitStrategy(bytes calldata data) external override onlyVaultManager returns (uint256) {
        uint256 amount = _decodeExitData(data);
        // withdraw token from lending
        IPool(strategyAddr).withdraw(TOKEN_ADDRESS, amount, address(vaultManager));

        return amount;
    }

    function constructExecuteStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function constructExitStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address, address) {
        return abi.decode(data, (ISatoshiCore, address, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function getPosition() external view override returns (address, uint256) {
        DataTypes.ReserveData memory data = IPool(strategyAddr).getReserveData(TOKEN_ADDRESS);
        return (TOKEN_ADDRESS, IERC20(data.aTokenAddress).balanceOf(address(this)));
    }
}
