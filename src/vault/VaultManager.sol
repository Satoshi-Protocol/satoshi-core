// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";
import {IVaultManager} from "../interfaces/vault/IVaultManager.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
/* 
    * @title VaultManager
    * @dev The contract is responsible for managing the vaults
    * Each TroveManager has a VaultManager
    */

contract VaultManager is IVaultManager, SatoshiOwnable, UUPSUpgradeable {
    address public troveManager;
    IERC20 public collateralToken;

    // priority / rule
    INYMVault[] public priority;

    mapping(address => bool) public whitelistVaults;
    mapping(address => uint256) public collateralAmounts;

    constructor() {
        _disableInitializers();
    }

    function initialize(ISatoshiCore _satoshiCore, address troveManager_) external override initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        troveManager = troveManager_;
        collateralToken = ITroveManager(troveManager_).collateralToken();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    // --- External functions ---

    function executeStrategy(address vault, uint256 amount) external onlyOwner {
        _checkWhitelistedVault(vault);

        collateralAmounts[vault] += amount;

        bytes memory data = INYMVault(vault).constructExecuteStrategyData(amount);
        collateralToken.transfer(vault, amount);
        INYMVault(vault).executeStrategy(data);

        emit ExecuteStrategy(vault, amount);
    }

    function exitStrategy(address vault, uint256 amount) external onlyOwner {
        _checkWhitelistedVault(vault);

        bytes memory data = INYMVault(vault).constructExitStrategyData(amount);
        INYMVault(vault).exitStrategy(data);

        collateralAmounts[vault] -= amount;

        emit ExitStrategy(vault, amount);
    }

    function exitStrategyByTroveManager(uint256 amount) external {
        require(msg.sender == troveManager, "VaultManager: Caller is not TroveManager");
        if (amount == 0) return;

        // assign a value to balanceAfter to prevent the priority being empty
        uint256 balanceAfter = collateralToken.balanceOf(address(this));
        uint256 withdrawAmount = amount;
        for (uint256 i; i < priority.length; i++) {
            if (balanceAfter >= amount) break;
            INYMVault vault = priority[i];
            bytes memory data = vault.constructExitStrategyData(withdrawAmount);
            uint256 exitAmount = vault.exitStrategy(data);
            collateralAmounts[address(vault)] -= exitAmount;
            withdrawAmount -= exitAmount;
            balanceAfter = collateralToken.balanceOf(address(this));

            emit ExitStrategy(address(vault), exitAmount);
        }

        // if the balance is still not enough
        uint256 actualTransferAmount = balanceAfter >= amount ? amount : balanceAfter;

        // transfer token to TroveManager
        collateralToken.approve(troveManager, actualTransferAmount);
        ITroveManager(troveManager).receiveCollFromPrivilegedVault(actualTransferAmount);
    }

    function setPriority(INYMVault[] memory _priority) external onlyOwner {
        delete priority;
        for (uint256 i; i < _priority.length; i++) {
            priority.push(_priority[i]);
        }
        emit PrioritySet(_priority);
    }

    function setWhiteListVault(address vault, bool status) external onlyOwner {
        whitelistVaults[vault] = status;
        emit WhiteListVaultSet(vault, status);
    }

    function transferCollToTroveManager(uint256 amount) external onlyOwner {
        collateralToken.approve(troveManager, amount);
        ITroveManager(troveManager).receiveCollFromPrivilegedVault(amount);

        emit CollateralTransferredToTroveManager(amount);
    }

    // --- Internal functions ---

    function _checkWhitelistedVault(address _vault) internal view {
        require(whitelistVaults[_vault], "VaultManager: Vault is not whitelisted");
    }
}
