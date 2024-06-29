// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ILendingPool} from "../interfaces/dependencies/vault/ILendingPool.sol";

contract AAVEVault is INYMVault, SatoshiOwnable, UUPSUpgradeable {
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

    function initialize(bytes calldata data) external initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address stableTokenAddress_) = _decodeInitializeData(data);
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

    function executeStrategy(bytes calldata data) external onlyOwner {
        uint256 amount = _decodeExecuteData(data);
        IERC20(STABLE_TOKEN_ADDRESS).approve(strategyAddr, amount);
        // deposit token to lending
        ILendingPool(strategyAddr).deposit(STABLE_TOKEN_ADDRESS, amount, address(this), 0);
    }

    function exitStrategy(bytes calldata data) external onlyOwner {
        uint256 amount = _decodeExitData(data);
        // withdraw token from lending
        ILendingPool(strategyAddr).withdraw(STABLE_TOKEN_ADDRESS, amount, nymAddr);
    }

    function transferTokenToNYM(uint256 amount) external onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(nymAddr, amount);
        emit TokenTransferredToNYM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address) {
        return abi.decode(data, (ISatoshiCore, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256 amount) {
        return abi.decode(data, (uint256));
    }
}
