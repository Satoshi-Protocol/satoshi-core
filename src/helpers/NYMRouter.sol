// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {SatoshiMath} from "../dependencies/SatoshiMath.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {IBorrowerOperations} from "../interfaces/core/IBorrowerOperations.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {ISatoshiPeriphery} from "./interfaces/ISatoshiPeriphery.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {IPriceFeed} from "../interfaces/dependencies/IPriceFeed.sol";
import {ILiquidationManager} from "../interfaces/core/ILiquidationManager.sol";
import {ISupraOraclePull} from "../interfaces/dependencies/priceFeed/ISupraOraclePull.sol";
import {IUniversalRouter} from "../interfaces/dependencies/IUniversalRouter.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";

/**
 * @title NYM Router
 *        Swap token to stable and vice versa
 */
contract NYMRouter {
    using SafeERC20 for IERC20;
    using SafeERC20Upgradeable for *;

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

    receive() external payable {
        // to receive native token
    }
}
