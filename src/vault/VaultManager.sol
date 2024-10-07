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

    function initialize(ISatoshiCore _satoshiCore) external override initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
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
        INYMVault(vault).executeStrategy(data);
    }

    function exitStrategy(address vault, uint256 amount) external onlyOwner {
        _checkWhitelistedVault(vault);

        bytes memory data;
        INYMVault(vault).exitStrategy(data);

        collateralAmounts[vault] -= amount;
    }

    function exitStrategyByTroveManager(uint256 amount) external {
        require(msg.sender == troveManager, "VaultManager: Caller is not TroveManager");

        uint256 balanceAfter;
        uint256 withdrawAmount = amount;
        for (uint256 i; i < priority.length; i++) {
            INYMVault vault = priority[i];
            bytes memory data = vault.constructExitStrategyData(withdrawAmount);
            uint256 exitAmount = vault.exitStrategy(data);
            collateralAmounts[address(vault)] -= exitAmount;
            balanceAfter = collateralToken.balanceOf(address(this));
            if (balanceAfter >= amount) break;
            withdrawAmount -= exitAmount;
        }

        // if the balance is still not enough
        uint256 acutalTransferAmount = balanceAfter >= amount ? amount : balanceAfter;

        // transfer token to TroveManager
        collateralToken.approve(troveManager, acutalTransferAmount);
        ITroveManager(troveManager).receiveCollFromPrivilegedVault(acutalTransferAmount);
    }

    function setPriority(INYMVault[] memory _priority) external onlyOwner {
        delete priority;
        for (uint256 i; i < _priority.length; i++) {
            priority.push(_priority[i]);
        }
    }

    function transferCollToTroveManager(uint256 amount) external onlyOwner {
        collateralToken.approve(troveManager, amount);
        ITroveManager(troveManager).receiveCollFromPrivilegedVault(amount);
    }

    // --- Internal functions ---

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address) {
        return abi.decode(data, (ISatoshiCore, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }

    function _checkWhitelistedVault(address _vault) internal view {
        require(whitelistVaults[_vault], "VaultManager: Vault is not whitelisted");
    }
}
