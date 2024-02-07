// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {IPrismaBase} from "../interfaces/dependencies/IPrismaBase.sol";

/*
 * Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
 * common functions.
 */
abstract contract PrismaBase is Initializable, IPrismaBase {
    uint256 public constant DECIMAL_PRECISION = 1e18;

    // Critical system collateral ratio. If the system's total collateral ratio (TCR) falls below the CCR, Recovery Mode is triggered.
    uint256 public constant CCR = 1500000000000000000; // 150%

    // Amount of debt to be locked in gas pool on opening troves
    uint256 public DEBT_GAS_COMPENSATION;

    uint256 public constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    constructor() {
        _disableInitializers();
    }

    function __PrismaBase_init(uint256 _gasCompensation) internal {
        DEBT_GAS_COMPENSATION = _gasCompensation;
    }

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(uint256 _debt) internal view returns (uint256) {
        return _debt + DEBT_GAS_COMPENSATION;
    }

    function _getNetDebt(uint256 _debt) internal view returns (uint256) {
        return _debt - DEBT_GAS_COMPENSATION;
    }

    // Return the amount of collateral to be drawn from a trove's collateral and sent as gas compensation.
    function _getCollGasCompensation(uint256 _entireColl) internal pure returns (uint256) {
        return _entireColl / PERCENT_DIVISOR;
    }

    function _requireUserAcceptsFee(uint256 _fee, uint256 _amount, uint256 _maxFeePercentage) internal pure {
        uint256 feePercentage = (_fee * DECIMAL_PRECISION) / _amount;
        require(feePercentage <= _maxFeePercentage, "Fee exceeded provided maximum");
    }
}
