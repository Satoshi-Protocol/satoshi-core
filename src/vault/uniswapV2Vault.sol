// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IPSMVault} from "../interfaces/vault/IPSMVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {IPegStability} from "../interfaces/core/IPegStability.sol";
import {IUniswapV2Router01} from "../interfaces/dependencies/vault/IUniswapV2Router01.sol";

contract UniV2Vault is SatoshiOwnable, UUPSUpgradeable {

    event StrategyAddrSet(address ceffuAddr);
    event PSMAddrSet(address psmAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToPSM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);

    address public strategyAddr;
    address public psmAddr;
    address public STABLE_TOKEN_ADDRESS;
    address public SAT_ADDRESS;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, address stableTokenAddress_, address satAddress_) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
        SAT_ADDRESS = satAddress_;
    }

    function setStrategyAddr(address _strategyAddr) external onlyOwner {
        strategyAddr = _strategyAddr;
        emit StrategyAddrSet(_strategyAddr);
    }

    function setPSMAddr(address _psmAddr) external onlyOwner {
        psmAddr = _psmAddr;
        emit PSMAddrSet(_psmAddr);
    }

    function executeStrategy(uint256 amount, uint256 minA, uint256 minB) external onlyOwner {
        // swap stable to sat in psm
        IERC20(STABLE_TOKEN_ADDRESS).approve(psmAddr, amount / 2);
        IPegStability(psmAddr).swapStableForSATPrivileged(address(this), amount / 2);
        // add liquidity on dex
        IUniswapV2Router01(strategyAddr).addLiquidity(STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amount / 2, amount / 2, minA, minB, address(this), block.timestamp + 100);
    }

    function exitStrategy(uint256 amount) external onlyOwner {
        // remove liquidity from dex
        IUniswapV2Router01(strategyAddr).removeLiquidity(STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amount, 0, 0, address(this), block.timestamp + 100);
        // swap sat to stable in psm
        uint256 previewAmount = IPegStability(psmAddr).previewSwapSATForStable(IERC20(SAT_ADDRESS).balanceOf(address(this)));
        IPegStability(psmAddr).swapSATForStablePrivileged(address(this), previewAmount);
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