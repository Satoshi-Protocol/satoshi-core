// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {ISatoshiOwnable} from "../interfaces/dependencies/ISatoshiOwnable.sol";

/**
 * @title Satoshi Ownable Contract
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/dependencies/PrismaOwnable.sol
 *
 */
abstract contract SatoshiOwnable is Initializable, ISatoshiOwnable {
    ISatoshiCore public SATOSHI_CORE;
    error InvalidSatoshiCore();

    constructor() {
        _disableInitializers();
    }

    function __SatoshiOwnable_init(ISatoshiCore _satoshiCore) internal {
        if(_satoshiCore.owner() == address(0)) revert InvalidSatoshiCore();
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
