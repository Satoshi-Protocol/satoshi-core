// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Coll is ERC20 {
    constructor() ERC20("Collateral", "COLL") {}

    function decimals() public view override returns (uint8) {
        return 8;
    }
}
