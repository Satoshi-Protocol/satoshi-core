// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {SatoshiLPToken} from "./SatoshiLPToken.sol";
import {ISatoshiLPFactory} from "../interfaces/core/ISatoshiLPFactory.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";

contract SatoshiLPFactory is SatoshiOwnable, ISatoshiLPFactory, UUPSUpgradeable {
    address[] public satoshiLPTokens;
    ICommunityIssuance public communityIssuance;

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, ICommunityIssuance _communityIssuance) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        communityIssuance = _communityIssuance;
    }

    function createSLP(string memory name, string memory symbol, IERC20 lpToken, uint32 claimStartTime)
        external
        onlyOwner
        returns (address)
    {
        SatoshiLPToken slp = new SatoshiLPToken(SATOSHI_CORE, name, symbol, lpToken, communityIssuance, claimStartTime);
        satoshiLPTokens.push(address(slp));
        return address(slp);
    }

    function setCommunityIssuance(ICommunityIssuance _communityIssuance) external onlyOwner {
        communityIssuance = _communityIssuance;
    }
}
