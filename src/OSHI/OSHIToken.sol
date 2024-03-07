// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";

contract OSHIToken is IOSHIToken, ERC20 {
    // --- ERC20 Data ---
    string internal constant _NAME = "OSHI";
    string internal constant _SYMBOL = "OSHI";
    string internal constant _VERSION = "1";

    // --- EIP 2612 Data ---

    // keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant permitTypeHash = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant _TYPE_HASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    // Cache the domain separator as an immutable value, but also store the chain id that it
    // corresponds to, in order to invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _CACHED_DOMAIN_SEPARATOR;
    uint256 private immutable _CACHED_CHAIN_ID;

    bytes32 private immutable _HASHED_NAME;
    bytes32 private immutable _HASHED_VERSION;

    address public immutable communityIssuanceAddress;
    address public immutable vaultAddress;

    mapping(address => uint256) private _nonces;

    uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

    // initial OSHI allocations (100,000,000 OSHI)
    // 45% to community issuance (45,000,000 OSHI)
    // 55% to vault (55,000,000 OSHI)
    uint256 internal constant COMMUNITY_ALLOCATION = 45 * _1_MILLION;
    uint256 internal constant VAULT_ALLOCATION = 55 * _1_MILLION;

    // --- Functions ---

    constructor(address _communityIssuanceAddress, address _vaultAddress) ERC20(_NAME, _SYMBOL) {
        bytes32 hashedName = keccak256(bytes(_NAME));
        bytes32 hashedVersion = keccak256(bytes(_VERSION));

        _HASHED_NAME = hashedName;
        _HASHED_VERSION = hashedVersion;
        _CACHED_CHAIN_ID = block.chainid;
        _CACHED_DOMAIN_SEPARATOR = _buildDomainSeparator(_TYPE_HASH, hashedName, hashedVersion);

        communityIssuanceAddress = _communityIssuanceAddress;
        vaultAddress = _vaultAddress;

        // --- Initial OSHI allocations ---
        // mint to community issuance
        _mint(_communityIssuanceAddress, COMMUNITY_ALLOCATION);

        // mint to vault
        _mint(_vaultAddress, VAULT_ALLOCATION);
    }

    // --- EIP 2612 functionality ---

    function domainSeparator() public view override returns (bytes32) {
        if (block.chainid == _CACHED_CHAIN_ID) {
            return _CACHED_DOMAIN_SEPARATOR;
        } else {
            return _buildDomainSeparator(_TYPE_HASH, _HASHED_NAME, _HASHED_VERSION);
        }
    }

    function permit(address owner, address spender, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external
        override
    {
        require(deadline >= block.timestamp, "OSHI: expired deadline");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                keccak256(abi.encode(permitTypeHash, owner, spender, amount, _nonces[owner]++, deadline))
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(recoveredAddress == owner, "OSHI: invalid signature");
        _approve(owner, spender, amount);
    }

    function nonces(address owner) external view override returns (uint256) {
        // FOR EIP 2612
        return _nonces[owner];
    }

    // --- Internal operations ---

    function _buildDomainSeparator(bytes32 typeHash, bytes32 name_, bytes32 version_) private view returns (bytes32) {
        return keccak256(abi.encode(typeHash, name_, version_, block.chainid, address(this)));
    }

    function _beforeTokenTransfer(address, address to, uint256) internal virtual override {
        require(to != address(this), "ERC20: transfer to the token address");
    }
}
