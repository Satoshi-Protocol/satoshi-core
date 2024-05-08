// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface IOSHIToken is IERC20Upgradeable {
    function vaultAddress() external view returns (address);
    function communityIssuanceAddress() external view returns (address);
    function initialize(ISatoshiCore _satoshiCore, address _communityIssuanceAddress, address _vaultAddress) external;
}
