// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/SLP/SatoshiLPToken.sol";
import "../src/interfaces/core/ICommunityIssuance.sol";

contract SLPTokenTester is SatoshiLPToken {
    constructor(ISatoshiCore _satoshiCore, IERC20 _lpToken, ICommunityIssuance _communityIssuance)
        SatoshiLPToken(_satoshiCore, "SLP", "SLP", _lpToken, _communityIssuance, 0)
    {}

    function unprotectedMint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }

    function unprotectedBurn(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }

    function callInternalApprove(address owner, address spender, uint256 amount) external {
        _approve(owner, spender, amount);
    }
}
