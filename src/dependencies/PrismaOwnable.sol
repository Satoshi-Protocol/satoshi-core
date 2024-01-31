// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPrismaCore} from "../interfaces/IPrismaCore.sol";
import {IPrismaOwnable} from "../interfaces/IPrismaOwnable.sol";

/**
 * @title Prisma Ownable
 *     @notice Contracts inheriting `PrismaOwnable` have the same owner as `PrismaCore`.
 *             The ownership cannot be independently modified or renounced.
 */
contract PrismaOwnable is IPrismaOwnable {
    IPrismaCore public immutable PRISMA_CORE;

    constructor(IPrismaCore _prismaCore) {
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
