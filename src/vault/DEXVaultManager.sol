// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";
import {IDEXVaultManager} from "../interfaces/vault/IDEXVaultManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
/* 
    * @title DEXVaultManager
    * @dev The contract is responsible for managing the dex vaults
    * Each token has a DexVaultManager
    * Distribute token to vaults to mint a position
    * Nexus Yield Manager -> Vault -> strategy
    */

contract DEXVaultManager is IDEXVaultManager, SatoshiOwnable, UUPSUpgradeable {
    IERC20 public token;
    IDebtToken public debtToken;
    mapping(address => bool) public whitelistVaults;
    // vault => tokenAmount
    mapping(address => uint256) public tokenOutput;

    constructor() {
        _disableInitializers();
    }

    function initialize(ISatoshiCore _satoshiCore, address _debtToken, address _token) external override initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        debtToken = IDebtToken(_debtToken);
        token = IERC20(_token);
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    // --- External functions ---

    function executeStrategy(address vault, bytes calldata data) external onlyOwner {
        _checkWhitelistedVault(vault);
        token.approve(vault, type(uint256).max);
        INYMVault(vault).executeStrategy(data);
        emit ExecuteStrategy(vault, data);
    }

    function executeCall(address vault, address dest, bytes calldata data) external onlyOwner {
        _checkWhitelistedVault(vault);
        INYMVault(vault).executeCall(dest, data);
        emit ExecuteCall(vault, dest, data);
    }

    function setWhiteListVault(address vault, bool status) external onlyOwner {
        whitelistVaults[vault] = status;
        emit WhiteListVaultSet(vault, status);
    }

    function mintDebtToken(uint256 amount) external {
        _checkWhitelistedVault(msg.sender);
        debtToken.mint(msg.sender, amount);
    }

    function burnDebtToken(uint256 amount) external {
        _checkWhitelistedVault(msg.sender);
        debtToken.burn(msg.sender, amount);
    }

    // --- Internal functions ---

    function _checkWhitelistedVault(address _vault) internal view {
        if (!whitelistVaults[_vault]) revert VaultNotWhitelisted();
    }
}
