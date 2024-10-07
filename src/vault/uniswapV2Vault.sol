// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";
import {IUniswapV2Router01} from "../interfaces/dependencies/vault/IUniswapV2Router01.sol";
import {VaultCore} from "./VaultCore.sol";

contract UniV2Vault is VaultCore {
    address public SAT_ADDRESS;
    address public PAIR_ADDRESS;

    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address stableTokenAddress_, address satAddress_, address pair_) =
            _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        STABLE_TOKEN_ADDRESS = stableTokenAddress_;
        SAT_ADDRESS = satAddress_;
        PAIR_ADDRESS = pair_;
    }

    function executeStrategy(bytes calldata data) external override onlyOwner {
        (uint256 amountA, uint256 amountB, uint256 minA, uint256 minB) = _decodeExecuteData(data);
        // swap stable to sat in nym
        IERC20(STABLE_TOKEN_ADDRESS).approve(nymAddr, amountA);
        INexusYieldManager(nymAddr).swapInPrivileged(STABLE_TOKEN_ADDRESS, address(this), amountA);
        require(IERC20(SAT_ADDRESS).balanceOf(address(this)) == amountB, "balance not match");

        IERC20(STABLE_TOKEN_ADDRESS).approve(strategyAddr, amountA);
        IERC20(SAT_ADDRESS).approve(strategyAddr, amountB);
        // add liquidity on dex
        IUniswapV2Router01(strategyAddr).addLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amountA, amountB, minA, minB, address(this), block.timestamp + 100
        );
    }

    function exitStrategy(bytes calldata data) external override onlyOwner returns (uint256) {
        uint256 amount = _decodeExitData(data);
        IERC20(PAIR_ADDRESS).approve(strategyAddr, amount);
        // remove liquidity from dex
        IUniswapV2Router01(strategyAddr).removeLiquidity(
            STABLE_TOKEN_ADDRESS, SAT_ADDRESS, amount, 0, 0, address(this), block.timestamp + 100
        );
        // swap sat to stable in nym
        uint256 previewAmount = INexusYieldManager(nymAddr).convertDebtTokenToAssetAmount(
            STABLE_TOKEN_ADDRESS, IERC20(SAT_ADDRESS).balanceOf(address(this))
        );
        uint256 swapOutAmount =
            INexusYieldManager(nymAddr).swapOutPrivileged(STABLE_TOKEN_ADDRESS, address(this), previewAmount);

        return swapOutAmount;
    }

    function constructExecuteStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function constructExitStrategyData(uint256 amount) external pure override returns (bytes memory) {
        return abi.encode(amount);
    }

    function _decodeInitializeData(bytes calldata data)
        internal
        pure
        returns (ISatoshiCore, address, address, address)
    {
        return abi.decode(data, (ISatoshiCore, address, address, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (uint256, uint256, uint256, uint256) {
        return abi.decode(data, (uint256, uint256, uint256, uint256));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }
}
