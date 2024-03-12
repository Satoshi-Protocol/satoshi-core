// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Team / Advisor Vesting Contract
 *        Rule: 12 month cliff, 30 month linear vesting
 *
 */

contract Vesting is Ownable {
    using SafeERC20 for IERC20;
    
    event TokenReleased(address indexed, uint256);
    event TokenVested(address, uint256, uint64);

    uint256 private _erc20Released;
    uint64 private immutable _start;
    uint64 private constant _duration = 30 days * 30;
    uint64 private constant _TWELVE_MONTHS = 30 days * 12;
    IERC20 public immutable token;  // OSHI token
    
    /**
     * @dev Sets the sender as the satoshi owner, the beneficiary as the pending owner, the start timestamp and the
     * vesting duration of the vesting wallet.
     */
    constructor(address _token, uint256 _amount, address _beneficiary, uint64 _startTimestamp) Ownable() {
        require(_beneficiary != address(0), "TeamVesting: beneficiary is the zero address");
        _start = _startTimestamp + _TWELVE_MONTHS; // 12 month cliff
        token = IERC20(_token);
        _transferOwnership(_beneficiary);

        // transfer OSHI token to this contract
        token.safeTransferFrom(msg.sender, address(this), _amount);
        emit TokenVested(_beneficiary, _amount, _start);
    }

    /**
     * @dev Getter for the start timestamp.
     */
    function start() public view virtual returns (uint256) {
        return _start;
    }

    /**
     * @dev Getter for the vesting duration.
     */
    function duration() public view virtual returns (uint256) {
        return _duration;
    }

    /**
     * @dev Getter for the end timestamp.
     */
    function end() public view virtual returns (uint256) {
        return start() + duration();
    }

    /**
     * @dev Amount of token already released
     */
    function released() public view virtual returns (uint256) {
        return _erc20Released;
    }

    /**
     * @dev Getter for the amount of releasable `token` tokens. `token` should be the address of an
     * IERC20 contract.
     */
    function releasable() public view virtual returns (uint256) {
        return vestedAmount(uint64(block.timestamp)) - released();
    }

    /**
     * @dev Release the tokens that have already vested.
     *
     * Emits a {TokenReleased} event.
     */
    function release() public virtual {
        uint256 amount = releasable();
        _erc20Released += amount;
        emit TokenReleased(address(token), amount);
        token.safeTransfer(owner(), amount);
    }

    /**
     * @dev Calculates the amount of tokens that has already vested. Default implementation is a linear vesting curve.
     */
    function vestedAmount(uint64 timestamp) public view virtual returns (uint256) {
        return _vestingSchedule(token.balanceOf(address(this)) + released(), timestamp);
    }

    /**
     * @dev Virtual implementation of the vesting formula. This returns the amount vested, as a function of time, for
     * an asset given its total historical allocation.
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view virtual returns (uint256) {
        if (timestamp < start()) {
            return 0;
        } else if (timestamp >= end()) {
            return totalAllocation;
        } else {
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }

}