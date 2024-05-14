// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface IOSHIToken is IERC20Upgradeable {
    function initialize(ISatoshiCore _satoshiCore) external;
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}
