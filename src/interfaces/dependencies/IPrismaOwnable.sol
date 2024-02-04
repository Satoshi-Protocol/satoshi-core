// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IPrismaCore} from "../core/IPrismaCore.sol";

interface IPrismaOwnable {
    function PRISMA_CORE() external view returns (IPrismaCore);

    function owner() external view returns (address);

    function guardian() external view returns (address);
}
