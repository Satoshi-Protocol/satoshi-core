// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IPSMVault} from "../interfaces/vault/IPSMVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ILendingPool} from "../interfaces/dependencies/vault/ILendingPool.sol";

contract AAVEVault is IPSMVault, SatoshiOwnable, UUPSUpgradeable {
    address public strategyAddr;
    address public psmAddr;
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

    function setPSMAddr(address _psmAddr) external onlyOwner {
        psmAddr = _psmAddr;
        emit PSMAddrSet(_psmAddr);
    }

    function executeStrategy(uint256 amount) external onlyOwner {
        // deposit token to lending
        ILendingPool(strategyAddr).deposit(STABLE_TOKEN_ADDRESS, amount, address(this), 0);
    }

    function exitStrategy(uint256 amount) external onlyOwner {
        // withdraw token from lending
        ILendingPool(strategyAddr).withdraw(STABLE_TOKEN_ADDRESS, amount, psmAddr);
    }

    function transferTokenToPSM(uint256 amount) external onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(psmAddr, amount);
        emit TokenTransferredToPSM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }
}