// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SatoshiOwnable} from "../dependencies/SatoshiOwnable.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";

/**
 * @title Reserve Contract
 *        Rule: unlock 2.1% every 6 months, total 60 months
 *
 */
contract Reserve is SatoshiOwnable {
    using SafeERC20 for IERC20;

    event TokenReleased(address indexed, uint256);
    event TokenVested(address, uint256, uint64);

    uint64 private immutable _start;
    uint64 private constant _duration = 60; // 60 months
    uint64 private constant _MONTH = 30 days;
    uint64 private constant _PERIOD = 6;
    uint256 internal constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
    uint256 private _released;
    uint256 private _totalAmount;
    uint256 private _eachPeriodReleasedAmount; // 2.1% every 6 months
    IERC20 public immutable token; // OSHI token

    /**
     * @dev Sets the satoshi owner as the owner, the start timestamp and the
     * vesting duration of the vesting wallet.
     */
    constructor(ISatoshiCore _satoshiCore, address _token, uint256 _amount, uint64 _startTimestamp) {
        require(_startTimestamp >= block.timestamp, "Reserve: start is before current time");
        __SatoshiOwnable_init(_satoshiCore);
        _start = _startTimestamp;
        token = IERC20(_token);
        _totalAmount = _amount;
        _eachPeriodReleasedAmount = _amount / (_duration / _PERIOD);
        emit TokenVested(owner(), _amount, _start);
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration (months).
     */
    function duration() public pure returns (uint256) {
        return _duration;
    }

    /**
     * @dev Amount of token already released
     */
    function released() public view returns (uint256) {
        return _released;
    }

    function totalAmount() public view returns (uint256) {
        return _totalAmount;
    }

    function eachPeriodReleasedAmount() public view returns (uint256) {
        return _eachPeriodReleasedAmount;
    }

    function releasable() public view returns (uint256) {
        uint256 periodElapsed = (block.timestamp - start()) / (_PERIOD * _MONTH) + 1;
        uint256 toRelease = periodElapsed * eachPeriodReleasedAmount();
        if (toRelease > _totalAmount) {
            toRelease = _totalAmount;
        }
        return toRelease - released();
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokenReleased} event.
     */
    function release() public {
        require(block.timestamp >= start(), "Reserve: current time is before start");
        uint256 amount = releasable();
        _released += amount;
        emit TokenReleased(address(token), amount);
        token.safeTransfer(owner(), amount);
    }
}
