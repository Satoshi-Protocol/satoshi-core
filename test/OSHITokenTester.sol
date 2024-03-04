// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "../src/OSHI/OSHIToken.sol";
import "../src/interfaces/core/ICommunityIssuance.sol";

contract OSHITokenTester is OSHIToken {
    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 private immutable _PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    constructor(address _communityIssuance, address _vaultAddress) OSHIToken(_communityIssuance, _vaultAddress) {}

    function unprotectedMint(address _account, uint256 _amount) external {
        _mint(_account, _amount);
    }

    function unprotectedBurn(address _account, uint256 _amount) external {
        _burn(_account, _amount);
    }

    function callInternalApprove(address owner, address spender, uint256 amount) external {
        _approve(owner, spender, amount);
    }

    function getDigest(address owner, address spender, uint256 amount, uint256 nonce, uint256 deadline)
        external
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encodePacked(
                uint16(0x1901),
                domainSeparator(),
                keccak256(abi.encode(_PERMIT_TYPEHASH, owner, spender, amount, nonce, deadline))
            )
        );
    }

    function recoverAddress(bytes32 digest, uint8 v, bytes32 r, bytes32 s) external pure returns (address) {
        return ecrecover(digest, v, r, s);
    }
}
