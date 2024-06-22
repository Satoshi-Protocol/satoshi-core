// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

contract SimpleVault is INYMVault, SatoshiOwnable, UUPSUpgradeable {
    address public strategyAddr;
    address public nymAddr;
    address public STABLE_TOKEN_ADDRESS;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, address stableTokenAddress_) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
    }

    function setStrategyAddr(address _strategyAddr) external onlyOwner {
        strategyAddr = _strategyAddr;
        emit StrategyAddrSet(_strategyAddr);
    }

    function setNYMAddr(address _nymAddr) external onlyOwner {
        nymAddr = _nymAddr;
        emit NYMAddrSet(_nymAddr);
    }

    function executeStrategy(uint256 amount) external onlyOwner {
        // execute strategy: transfer token to ceffu
        IERC20(STABLE_TOKEN_ADDRESS).transfer(strategyAddr, amount);
        emit TokenTransferredToStrategy(amount);
    }

    // todo
    function exitStrategy(uint256 amount) external onlyOwner {}

    function transferTokenToNYM(uint256 amount) external onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(nymAddr, amount);
        emit TokenTransferredToNYM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }
}
