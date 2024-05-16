// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

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

    // --- Functions ---
    constructor() {
        _disableInitializers();
    }

    /// @notice Override the _authorizeUpgrade function inherited from UUPSUpgradeable contract
    // solhint-disable-next-line no-empty-blocks
    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
        // No additional authorization logic is needed for this contract
    }

    function initialize(ISatoshiCore _satoshiCore) external initializer {
        __UUPSUpgradeable_init_unchained();
        __SatoshiOwnable_init(_satoshiCore);
        __ERC20_init(_NAME, _SYMBOL);
        __ERC20Permit_init(_NAME);
    }

    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}
