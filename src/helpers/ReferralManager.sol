// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IReferralManager} from "./interfaces/IReferralManager.sol";
import {ISatoshiBORouter} from "./interfaces/ISatoshiBORouter.sol";
import {ITroveManager} from "../interfaces/core/ITroveManager.sol";

contract ReferralManager is IReferralManager, Ownable {
    ISatoshiBORouter public immutable satoshiBORouter;

    uint256 public startTimestamp;
    uint256 public endTimestamp;

    uint256 internal totalPoints;
    // borrower => referrer
    mapping(address => address) internal referrers;
    // referrer => points
    mapping(address => uint256) internal points;

    event SetStartTimestamp(uint256 _startTimestamp);
    event SetEndTimestamp(uint256 _endTimestamp);
    event ExecuteReferral(address indexed borrower, address indexed referrer, uint256 points);

    error InvalidTimestamp(uint256 timestamp);
    error InvalidZeroAddress();
    error InvalidSelfReferral();
    error InvalidReferrer(address _referrer);
    error Unauthorized(address _caller);

    modifier onlySatoshiBORouter() {
        if (msg.sender != address(satoshiBORouter)) revert Unauthorized(msg.sender);
        _;
    }

    constructor(ISatoshiBORouter _satoshiBORouter, uint256 _startTimestamp, uint256 _endTimestamp) {
        if (address(_satoshiBORouter) == address(0)) revert InvalidZeroAddress();

        satoshiBORouter = _satoshiBORouter;
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
    }

    function executeReferral(address _borrower, address _referrer, uint256 _points, ITroveManager troveManager)
        external
        onlySatoshiBORouter
    {
        // only execute referral if it's active
        if (!_isReferralActive()) return;
        // no referrer
        if (_referrer == address(0)) return;
        // cannot refer self
        if (_borrower == _referrer) revert InvalidSelfReferral();
        // cannot refer a non-trove
        if (troveManager.getTroveStatus(_referrer) == 0) revert InvalidReferrer(_referrer);

        address currentReferrer = referrers[_borrower];
        if (currentReferrer == address(0)) {
            _setReferrer(_borrower, _referrer);
        } else {
            // use existing referrer
            _referrer = currentReferrer;
        }

        _addPoint(_referrer, _points);
        _addTotalPoints(_points);

        emit ExecuteReferral(_borrower, _referrer, _points);
    }

    function isReferralActive() external view returns (bool) {
        return _isReferralActive();
    }

    function _addPoint(address _account, uint256 _points) internal {
        points[_account] += _points;
    }

    function _addTotalPoints(uint256 _points) internal {
        totalPoints += _points;
    }

    function _setReferrer(address _account, address _referrer) internal {
        referrers[_account] = _referrer;
    }

    function _isReferralActive() internal view returns (bool) {
        uint256 _timestamp = block.timestamp;
        return _timestamp >= startTimestamp && _timestamp <= endTimestamp;
    }

    function getTotalPoints() external view returns (uint256) {
        return totalPoints;
    }

    function getBatchPoints(address[] calldata _accounts) external view returns (uint256[] memory) {
        uint256[] memory _points = new uint256[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            _points[i] = points[_accounts[i]];
        }
        return _points;
    }

    function getPoints(address _account) external view returns (uint256) {
        return points[_account];
    }

    function getBatchReferrers(address[] calldata _accounts) external view returns (address[] memory) {
        address[] memory _referrers = new address[](_accounts.length);
        for (uint256 i = 0; i < _accounts.length; i++) {
            _referrers[i] = referrers[_accounts[i]];
        }
        return _referrers;
    }

    function getReferrer(address _account) external view returns (address) {
        return referrers[_account];
    }

    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        if (_startTimestamp > endTimestamp) revert InvalidTimestamp(_startTimestamp);
        startTimestamp = _startTimestamp;
        emit SetStartTimestamp(_startTimestamp);
    }

    function setEndTimestamp(uint256 _endTimestamp) external onlyOwner {
        if (_endTimestamp < startTimestamp) revert InvalidTimestamp(_endTimestamp);
        endTimestamp = _endTimestamp;
        emit SetEndTimestamp(_endTimestamp);
    }
}
