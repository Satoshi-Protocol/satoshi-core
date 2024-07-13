// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICommunityIssuance} from "./ICommunityIssuance.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface ISatoshiLPFactory is ISatoshiOwnable {
    function createSLP(string memory name, string memory symbol, IERC20 lpToken, uint32 claimStartTime)
        external
        returns (address);
    function satoshiLPTokens(uint256) external view returns (address);
    function initialize(ISatoshiCore _satoshiCore, ICommunityIssuance _communityIssuance) external;
    function setCommunityIssuance(ICommunityIssuance _communityIssuance) external;
    function communityIssuance() external view returns (ICommunityIssuance);
}
