// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IDebtToken} from "../src/interfaces/core/IDebtToken.sol";

contract FlashloanTester is IERC3156FlashBorrower {
    IDebtToken lender;

    constructor (IDebtToken lender_) {
        lender = lender_;
    }

    // ERC-3156 Flash loan callback
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    ) public override returns(bytes32) {
        uint256 repayment = amount + fee;
        require(
            msg.sender == address(lender),
            "FlashBorrower: Untrusted lender"
        );
        require(
            initiator == address(this),
            "FlashBorrower: Untrusted loan initiator"
        );
        // do sth
        IDebtToken(token).approve(address(lender), repayment);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Initiate a flash loan
    function flashBorrow(
        address token,
        uint256 amount
    ) public {
        lender.flashLoan(IERC3156FlashBorrower(this), token, amount, "");
    }
}