// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {INYMVault} from "./INYMVault.sol";

interface IVaultManager {
    event WhiteListVaultSet(address vault, bool isWhitelisted);
    event PrioritySet(INYMVault[] priority);
    event CollateralTransferredToTroveManager(uint256 amount);
    event ExecuteStrategy(address vault, uint256 amount);
    event ExitStrategy(address vault, uint256 amount);

    function executeStrategy(address, uint256) external;
    function exitStrategy(address, uint256) external;
    function initialize(ISatoshiCore, address) external;
    function exitStrategyByTroveManager(uint256 amount) external;
    function setPriority(INYMVault[] memory _priority) external;
    function transferCollToTroveManager(uint256 amount) external;
    function setWhiteListVault(address vault, bool status) external;
}
