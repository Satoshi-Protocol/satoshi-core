// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IGasPool} from "../interfaces/core/IGasPool.sol";

/**
 * @title Gas Pool Contract (Non-upgradeable)
 *        Mutated from:
 *        https://github.com/prisma-fi/prisma-contracts/blob/main/contracts/core/GasPool.sol
 *        https://github.com/liquity/dev/blob/main/packages/contracts/contracts/GasPool.sol
 *
 */
contract GasPool is IGasPool {
// do nothing, as the core contracts have permission to send to and burn from this address
}
