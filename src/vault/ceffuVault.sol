// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ICeffuVault} from "../interfaces/vault/ICeffuVault.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";

contract CeffuVault is ICeffuVault, SatoshiOwnable, UUPSUpgradeable {
    address public ceffuAddr;
    address public psmAddr;

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
    }

    function setCEFFUAddr(address _ceffuAddr) external onlyOwner {
        ceffuAddr = _ceffuAddr;
        emit CEFFUAddrSet(_ceffuAddr);
    }

    function setPSMAddr(address _psmAddr) external onlyOwner {
        psmAddr = _psmAddr;
        emit PSMAddrSet(_psmAddr);
    }

    function transferTokenToCeffu(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(ceffuAddr, amount);
        emit TokenTransferredToCeffu(token, amount);
    }

    function transferTokenToPSM(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(psmAddr, amount);
        emit TokenTransferredToPSM(token, amount);
    }
}