// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";
import {INYMVault} from "./INYMVault.sol";

interface IDEXVaultManager {
    event WhiteListVaultSet(address vault, bool isWhitelisted);
    event PrioritySet(INYMVault[] priority);
    event CollateralTransferredToTroveManager(uint256 amount);
    event ExecuteStrategy(address vault, bytes data);
    event ExecuteCall(address vault, address dest, bytes data);

    error VaultNotWhitelisted();

    function executeStrategy(address, bytes calldata) external;
    function initialize(ISatoshiCore, address, address) external;
    function setWhiteListVault(address vault, bool status) external;
    function mintDebtToken(uint256 amount) external;
    function burnDebtToken(uint256 amount) external;
}
