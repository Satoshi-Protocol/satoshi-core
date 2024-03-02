// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface ICommunityIssuance {
    event SetAllocation(address indexed receiver, uint256 amount);
    event OSHITokenAddressSet(address _oshiTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);

    function transferAllocatedTokens(address receiver, uint256 amount) external;
    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external;
}
