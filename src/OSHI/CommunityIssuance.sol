// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";
import {IStabilityPool} from "../interfaces/core/IStabilityPool.sol";

contract CommunityIssuance is ICommunityIssuance, SatoshiOwnable, UUPSUpgradeable {
    IStabilityPool public stabilityPool;
    IOSHIToken public OSHIToken;

    mapping(address => uint256) public allocated; // allocate to troveManagers and SP
    mapping(address => uint256) public collected;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, IOSHIToken _oshiToken, IStabilityPool _stabilityPool)
        external
        initializer
    {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        OSHIToken = _oshiToken;
        stabilityPool = _stabilityPool;

        emit OSHITokenSet(_oshiToken);
        emit StabilityPoolSet(_stabilityPool);
    }

    function setAllocated(address[] calldata _recipients, uint256[] calldata _amounts) external onlyOwner {
        require(_recipients.length == _amounts.length, "Community Issuance: Arrays must be of equal length");
        for (uint256 i; i < _recipients.length; ++i) {
            allocated[_recipients[i]] = _amounts[i];
            emit SetAllocation(_recipients[i], _amounts[i]);
        }
    }

    function transferAllocatedTokens(address receiver, uint256 amount) external {
        if (amount > 0) {
            require(collected[msg.sender] >= amount, "Community Issuance: Insufficient balance");
            collected[msg.sender] -= amount;
            OSHIToken.transfer(receiver, amount);
        }
    }

    function collectAllocatedTokens(uint256 amount) external {
        if (amount > 0) {
            require(allocated[msg.sender] >= amount, "Community Issuance: Insufficient balance");
            allocated[msg.sender] -= amount;
            collected[msg.sender] += amount;
        }
    }
}
