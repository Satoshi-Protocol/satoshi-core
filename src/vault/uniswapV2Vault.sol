// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {INexusYield} from "../interfaces/core/INexusYield.sol";
import {IUniswapV2Router01} from "../interfaces/dependencies/vault/IUniswapV2Router01.sol";

contract UniV2Vault is SatoshiOwnable, UUPSUpgradeable {
    event StrategyAddrSet(address ceffuAddr);
    event NYMAddrSet(address nymAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToNYM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);

    address public strategyAddr;
    address public nymAddr;
    address public STABLE_TOKEN_ADDRESS;
    address public SAT_ADDRESS;
    address public PAIR_ADDRESS;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, address stableTokenAddress_, address satAddress_, address pair_)
        external
        initializer
    {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
        SAT_ADDRESS = satAddress_;
        PAIR_ADDRESS = pair_;
    }

    function setStrategyAddr(address _strategyAddr) external onlyOwner {
        strategyAddr = _strategyAddr;
        emit StrategyAddrSet(_strategyAddr);
    }

    function setNYMAddr(address _nymAddr) external onlyOwner {
        nymAddr = _nymAddr;
        emit NYMAddrSet(_nymAddr);
    }

    function executeStrategy(uint256 amountA, uint256 amountB, uint256 minA, uint256 minB) external onlyOwner {
        // swap stable to sat in nym
        IERC20(STABLE_TOKEN_ADDRESS).approve(nymAddr, amountA);
        INexusYield(nymAddr).swapStableForSATPrivileged(address(this), amountA);
        require(IERC20(SAT_ADDRESS).balanceOf(address(this)) == amountB, "balance not match");

        IERC20(STABLE_TOKEN_ADDRESS).approve(strategyAddr, amountA);
        IERC20(SAT_ADDRESS).approve(strategyAddr, amountB);
        // add liquidity on dex
        IUniswapV2Router01(strategyAddr).addLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amountA, amountB, minA, minB, address(this), block.timestamp + 100
        );
    }

    function exitStrategy(uint256 amount) external onlyOwner {
        IERC20(PAIR_ADDRESS).approve(strategyAddr, amount);
        // remove liquidity from dex
        IUniswapV2Router01(strategyAddr).removeLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amount, 0, 0, address(this), block.timestamp + 100
        );
        // swap sat to stable in nym
        uint256 previewAmount =
            INexusYield(nymAddr).convertSATToStableAmount(IERC20(SAT_ADDRESS).balanceOf(address(this)));
        INexusYield(nymAddr).swapSATForStablePrivileged(address(this), previewAmount);
    }

    function transferTokenToNYM(uint256 amount) external onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(nymAddr, amount);
        emit TokenTransferredToNYM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }
}
