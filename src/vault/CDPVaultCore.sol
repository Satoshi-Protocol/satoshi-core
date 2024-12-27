// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ICDPVault} from "../interfaces/vault/ICDPVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

abstract contract CDPVaultCore is ICDPVault, SatoshiOwnable, UUPSUpgradeable {
    address public strategyAddr;
    address public TOKEN_ADDRESS;
    address public vaultManager;

    constructor() {
        _disableInitializers();
    }

    function initialize(bytes calldata data) external virtual;

    function executeStrategy(bytes calldata data) external virtual;

    function exitStrategy(bytes calldata data) external virtual returns (uint256);

    function constructExecuteStrategyData(uint256 amount) external pure virtual returns (bytes memory);

    function constructExitStrategyData(uint256 amount) external pure virtual returns (bytes memory);

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view virtual override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function setStrategyAddr(address _strategyAddr) external virtual onlyOwner {
        strategyAddr = _strategyAddr;
        emit StrategyAddrSet(_strategyAddr);
    }

    function transferToken(address token, address to, uint256 amount) external virtual onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }
}
