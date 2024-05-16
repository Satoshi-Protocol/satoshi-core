// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";
import {IOSHIToken} from "./IOSHIToken.sol";
import {IStabilityPool} from "./IStabilityPool.sol";
import {ISatoshiCore} from "./ISatoshiCore.sol";

interface ICommunityIssuance is ISatoshiOwnable {
    event SetAllocation(address indexed receiver, uint256 amount);
    event OSHITokenSet(IOSHIToken _oshiToken);
    event StabilityPoolSet(IStabilityPool _stabilityPool);

    function transferAllocatedTokens(address receiver, uint256 amount) external;
    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external;
    function collectAllocatedTokens(uint256 amount) external;
    function allocated(address) external view returns (uint256);
    function collected(address) external view returns (uint256);
    function stabilityPool() external view returns (IStabilityPool);
    function OSHIToken() external view returns (IOSHIToken);
    function initialize(ISatoshiCore _satoshiCore, IOSHIToken _oshiToken, IStabilityPool _stabilityPool) external;
}
