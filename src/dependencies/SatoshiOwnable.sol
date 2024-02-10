// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ISatoshiOwnable} from "../interfaces/dependencies/ISatoshiOwnable.sol";

/**
 * @title Satoshi Ownable
 *     @notice Contracts inheriting `SatoshiOwnable` have the same owner as `SatoshiCore`.
 *             The ownership cannot be independently modified or renounced.
 */
abstract contract SatoshiOwnable is Initializable, ISatoshiOwnable {
    ISatoshiCore public SATOSHI_CORE;

    function __SatoshiOwnable_init(ISatoshiCore _satoshiCore) internal {
        SATOSHI_CORE = _satoshiCore;
    }

    modifier onlyOwner() {
        require(msg.sender == SATOSHI_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address) {
        return SATOSHI_CORE.owner();
    }

    function guardian() public view returns (address) {
        return SATOSHI_CORE.guardian();
    }
}
