// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {ERC20PermitUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {IOSHIToken} from "../interfaces/core/IOSHIToken.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";

contract OSHIToken is IOSHIToken, SatoshiOwnable, UUPSUpgradeable, ERC20Upgradeable, ERC20PermitUpgradeable {
    // --- ERC20 Data ---
    string internal constant _NAME = "OSHI";
    string internal constant _SYMBOL = "OSHI";

    address public communityIssuanceAddress;
    address public vaultAddress;

    uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24

    uint256 internal constant COMMUNITY_ALLOCATION = 45 * _1_MILLION;
    uint256 internal constant VAULT_ALLOCATION = 55 * _1_MILLION;

    mapping(address => bool) public minters;

    // --- Functions ---

    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore, address _communityIssuanceAddress, address _vaultAddress)
        external
        initializer
    {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Permit_init(_NAME);

        communityIssuanceAddress = _communityIssuanceAddress;
        vaultAddress = _vaultAddress;

        // --- Initial OSHI allocations ---
        // mint to community issuance
        _mint(_communityIssuanceAddress, COMMUNITY_ALLOCATION);

        // mint to vault
        _mint(_vaultAddress, VAULT_ALLOCATION);
    }

    modifier onlyWhiteList() {
        require(minters[msg.sender], "OSHI: Not in whitelist");
        _;
    }

    function setWhiteList(address _minter, bool _status) external onlyOwner {
        minters[_minter] = _status;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function mintByWhiteList(address account, uint256 amount) external onlyWhiteList {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }

    function burnByWhiteList(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
