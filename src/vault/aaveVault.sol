// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ILendingPool} from "../interfaces/dependencies/vault/ILendingPool.sol";
import {VaultCore} from "./VaultCore.sol";

contract AAVEVault is VaultCore {
    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address stableTokenAddress_) = _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
    }

    function executeStrategy(bytes calldata data) external override onlyOwner {
        uint256 amount = _decodeExecuteData(data);
        IERC20(STABLE_TOKEN_ADDRESS).approve(strategyAddr, amount);
        // deposit token to lending
        ILendingPool(strategyAddr).deposit(STABLE_TOKEN_ADDRESS, amount, address(this), 0);
    }

    function exitStrategy(bytes calldata data) external override onlyOwner {
        uint256 amount = _decodeExitData(data);
        // withdraw token from lending
        ILendingPool(strategyAddr).withdraw(STABLE_TOKEN_ADDRESS, amount, nymAddr);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address) {
        return abi.decode(data, (ISatoshiCore, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }
}
