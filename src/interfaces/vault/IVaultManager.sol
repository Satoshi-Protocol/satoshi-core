// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {INYMVault} from "./INYMVault.sol";

interface IVaultManager {
    function executeStrategy(address, uint256) external;
    function exitStrategy(address, uint256) external;
    function initialize(ISatoshiCore) external;
    function exitStrategyByTroveManager(uint256 amount) external;
    function setPriority(INYMVault[] memory _priority) external;
    function transferCollToTroveManager(uint256 amount) external;
}
