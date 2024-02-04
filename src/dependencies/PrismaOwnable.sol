// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IPrismaCore} from "../interfaces/core/IPrismaCore.sol";
import {IPrismaOwnable} from "../interfaces/dependencies/IPrismaOwnable.sol";

/**
 * @title Prisma Ownable
 *     @notice Contracts inheriting `PrismaOwnable` have the same owner as `PrismaCore`.
 *             The ownership cannot be independently modified or renounced.
 */
abstract contract PrismaOwnable is Initializable, IPrismaOwnable {
    IPrismaCore public PRISMA_CORE;

    function __PrismaOwnable_init(IPrismaCore _prismaCore) internal initializer {
        PRISMA_CORE = _prismaCore;
    }

    modifier onlyOwner() {
        require(msg.sender == PRISMA_CORE.owner(), "Only owner");
        _;
    }

    function owner() public view returns (address) {
        return PRISMA_CORE.owner();
    }

    function guardian() public view returns (address) {
        return PRISMA_CORE.guardian();
    }
}
