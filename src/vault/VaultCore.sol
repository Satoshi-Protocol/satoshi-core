// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

abstract contract VaultCore is INYMVault, SatoshiOwnable, UUPSUpgradeable {
    address public strategyAddr;
    address public nymAddr;
    address public STABLE_TOKEN_ADDRESS;

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

    function setNYMAddr(address _nymAddr) external virtual onlyOwner {
        nymAddr = _nymAddr;
        emit NYMAddrSet(_nymAddr);
    }

    function transferTokenToNYM(uint256 amount) external virtual onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(nymAddr, amount);
        emit TokenTransferredToNYM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external virtual onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }
}
