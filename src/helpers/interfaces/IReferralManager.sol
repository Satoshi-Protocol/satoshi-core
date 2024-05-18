// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiPeriphery} from "./ISatoshiPeriphery.sol";
import {ITroveManager} from "../../interfaces/core/ITroveManager.sol";

interface IReferralManager {
    function satoshiPeriphery() external view returns (ISatoshiPeriphery);

    function startTimestamp() external view returns (uint256);

    function endTimestamp() external view returns (uint256);

    function executeReferral(address _borrower, address _referrer, uint256 _points, ITroveManager troveManager)
        external;

    function isReferralActive() external view returns (bool);

    function getTotalPoints() external view returns (uint256);

    function getBatchPoints(address[] calldata _accounts) external view returns (uint256[] memory);

    function getPoints(address _account) external view returns (uint256);

    function getBatchReferrers(address[] calldata _accounts) external view returns (address[] memory);

    function getReferrer(address _account) external view returns (address);

    function setStartTimestamp(uint256 _startTimestamp) external;

    function setEndTimestamp(uint256 _endTimestamp) external;
}
