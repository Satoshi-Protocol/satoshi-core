// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";
import {IUniswapV2Router01} from "../interfaces/dependencies/vault/IUniswapV2Router01.sol";
import {INYMVault} from "../interfaces/vault/INYMVault.sol";

contract UniV2Vault is INYMVault, SatoshiOwnable, UUPSUpgradeable {
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

    function initialize(bytes calldata data)
        external
        initializer
    {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address stableTokenAddress_, address satAddress_, address pair_) = _decodeInitializeData(data);
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

    function executeStrategy(bytes calldata data) external onlyOwner {
        (uint256 amountA, uint256 amountB, uint256 minA, uint256 minB) = _decodeExecuteData(data);
        // swap stable to sat in nym
        IERC20(STABLE_TOKEN_ADDRESS).approve(nymAddr, amountA);
        INexusYieldManager(nymAddr).swapStableForSATPrivileged(STABLE_TOKEN_ADDRESS, address(this), amountA);
        require(IERC20(SAT_ADDRESS).balanceOf(address(this)) == amountB, "balance not match");

        IERC20(STABLE_TOKEN_ADDRESS).approve(strategyAddr, amountA);
        IERC20(SAT_ADDRESS).approve(strategyAddr, amountB);
        // add liquidity on dex
        IUniswapV2Router01(strategyAddr).addLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amountA, amountB, minA, minB, address(this), block.timestamp + 100
        );
    }

    function exitStrategy(bytes calldata data) external onlyOwner {
        uint256 amount = _decodeExitData(data);
        IERC20(PAIR_ADDRESS).approve(strategyAddr, amount);
        // remove liquidity from dex
        IUniswapV2Router01(strategyAddr).removeLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amount, 0, 0, address(this), block.timestamp + 100
        );
        // swap sat to stable in nym
        uint256 previewAmount = INexusYieldManager(nymAddr).convertSATToStableAmount(
            STABLE_TOKEN_ADDRESS, IERC20(SAT_ADDRESS).balanceOf(address(this))
        );
        INexusYieldManager(nymAddr).swapSATForStablePrivileged(STABLE_TOKEN_ADDRESS, address(this), previewAmount);
    }

    function transferTokenToNYM(uint256 amount) external onlyOwner {
        IERC20(STABLE_TOKEN_ADDRESS).transfer(nymAddr, amount);
        emit TokenTransferredToNYM(amount);
    }

    function transferToken(address token, address to, uint256 amount) external onlyOwner {
        IERC20(token).transfer(to, amount);
        emit TokenTransferred(token, to, amount);
    }

    function _decodeInitializeData(bytes calldata data) internal pure returns (ISatoshiCore, address, address, address) {
        return abi.decode(data, (ISatoshiCore, address, address, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256, uint256, uint256, uint256) {
        return abi.decode(data, (uint256, uint256, uint256, uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }
}
