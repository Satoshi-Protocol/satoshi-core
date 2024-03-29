// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {SatoshiLPToken} from "./SatoshiLPToken.sol";
import {ISatoshiLPFactory} from "../interfaces/core/ISatoshiLPFactory.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ICommunityIssuance} from "../interfaces/core/ICommunityIssuance.sol";

contract SatoshiLPFactory is SatoshiOwnable, ISatoshiLPFactory {
    address[] public satoshiLPTokens;
    ICommunityIssuance public communityIssuance;

    constructor(ISatoshiCore _satoshiCore, ICommunityIssuance _communityIssuance) {
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
