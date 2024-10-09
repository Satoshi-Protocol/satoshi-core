// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {VaultCore} from "./VaultCore.sol";

contract SimpleVault is VaultCore {
    mapping(address => bool) public whitelist;

    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address stableTokenAddress_) = _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
    }

    modifier onlyWhitelisted() {
        require(msg.sender == owner() || whitelist[msg.sender], "SimpleVault: caller is not whitelisted");
        _;
    }

    function executeStrategy(bytes calldata data) external override onlyWhitelisted {
        uint256 amount = _decodeExecuteData(data);
        // execute strategy: transfer token to ceffu
        // IERC20(STABLE_TOKEN_ADDRESS).transfer(strategyAddr, amount);
        emit TokenTransferredToStrategy(amount);
    }

    // todo
    function exitStrategy(bytes calldata data) external override onlyWhitelisted returns (uint256) {
        uint256 amount = _decodeExitData(data);
        IERC20(STABLE_TOKEN_ADDRESS).transfer(msg.sender, amount);
        return amount;
    }

    function setWhitelist(address account, bool status) external onlyOwner {
        whitelist[account] = status;
        emit WhitelistSet(account, status);
    }

    function constructExecuteStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function constructExitStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address) {
        return abi.decode(data, (ISatoshiCore, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }
}
