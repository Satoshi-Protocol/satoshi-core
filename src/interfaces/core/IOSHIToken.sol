// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IOSHIToken is IERC20 {
    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;

    function domainSeparator() external view returns (bytes32);

    function nonces(address owner) external view returns (uint256);

    function permitTypeHash() external view returns (bytes32);

    function communityIssuanceAddress() external view returns (address);

    function vaultAddress() external view returns (address);
}
