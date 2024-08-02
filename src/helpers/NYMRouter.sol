// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniversalRouter} from "../interfaces/dependencies/IUniversalRouter.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";
import {IUniswapV2Router01} from "../interfaces/dependencies/IUniswapV2Router01.sol";

/**
 * @title NYM Router
 *        Swap token to stable and vice versa
 */
contract NYMRouter {
    IUniversalRouter public universalRouter;
    INexusYieldManager public nym;
    IUniswapV2Router01 public uniV2Router;

    constructor(address universalRouter_, address nym_, address uniV2Router_) {
        universalRouter = IUniversalRouter(universalRouter_);
        nym = INexusYieldManager(nym_);
        uniV2Router = IUniswapV2Router01(uniV2Router_);
    }

    function executeSwapInViaUniversalRouter(
        address asset,
        bytes calldata commands,
        bytes[] calldata inputs,
        uint256 deadline
    ) external payable {
        // swap token to stable
        uint256 stableAmountBefore = IERC20(asset).balanceOf(address(this));
        universalRouter.execute{value: msg.value}(commands, inputs, deadline);
        uint256 stableAmountAfter = IERC20(asset).balanceOf(address(this));
        uint256 stableAmount = stableAmountAfter - stableAmountBefore;
        IERC20(asset).approve(address(nym), stableAmount);
        // swapIn
        nym.swapIn(asset, msg.sender, stableAmount);
    }

    function executeSwapInViaUniV2Router(address asset, uint256 amountOut) external payable {
        uint256 stableAmountBefore = IERC20(asset).balanceOf(address(this));
        address[] memory path = new address[](2);
        path[0] = uniV2Router.WETH();
        path[1] = asset;
        // swap token to stable on uniswap
        uniV2Router.swapExactETHForTokens{value: msg.value}(amountOut, path, address(this), block.timestamp + 120);
        uint256 stableAmountAfter = IERC20(asset).balanceOf(address(this));
        uint256 stableAmount = stableAmountAfter - stableAmountBefore;
        IERC20(asset).approve(address(nym), stableAmount);
        // swapIn
        nym.swapIn(asset, msg.sender, stableAmount);
    }
}
