// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {INYMVault} from "./INYMVault.sol";

interface IVaultManager {
    event WhiteListVaultSet(address vault, bool isWhitelisted);
    event PrioritySet(address troveManager, INYMVault[] priority);
    event CollateralTransferredToTroveManager(address troveManager, uint256 amount);
    event ExecuteStrategy(address vault, bytes data);
    event ExitStrategy(address vault, uint256 amount);
    event ExecuteCall(address vault, address dest, bytes data);

    error VaultNotWhitelisted();
    error CallerIsNotTroveManager();

    function executeStrategy(address, bytes calldata) external;
    function initialize(ISatoshiCore) external;
    function exitStrategyByTroveManager(uint256 amount) external;
    function setPriority(address token, INYMVault[] memory _priority) external;
    function transferCollToTroveManager(address troveManager, uint256 amount) external;
    function setWhiteListVault(address vault, bool status) external;
    function mintDebtToken(uint256 amount) external;
    function burnDebtToken(uint256 amount) external;
}
