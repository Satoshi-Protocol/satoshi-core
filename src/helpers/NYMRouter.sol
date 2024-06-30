// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniversalRouter} from "../interfaces/dependencies/IUniversalRouter.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";

/**
 * @title NYM Router
 *        Swap token to stable and vice versa
 */
contract NYMRouter {

    IUniversalRouter public universalRouter;
    INexusYieldManager public nym;

    constructor(address universalRouter_, address nym_) {
        universalRouter = IUniversalRouter(universalRouter_);
        nym = INexusYieldManager(nym_);
    }

    function executeSwapIn(address asset, bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable {
        // swap token to stable
        uint256 stableAmountBefore = IERC20(asset).balanceOf(address(this));
        universalRouter.execute{value: msg.value}(commands, inputs, deadline);
        uint256 stableAmountAfter = IERC20(asset).balanceOf(address(this));
        uint256 stableAmount = stableAmountAfter - stableAmountBefore;
        IERC20(asset).approve(address(nym), stableAmount);
        // swapIn
        nym.swapStableForSAT(asset, msg.sender, stableAmount);
    }
}
