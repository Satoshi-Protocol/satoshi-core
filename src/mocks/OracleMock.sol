// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AggregatorV3Interface} from "../interfaces/dependencies/priceFeed/AggregatorV3Interface.sol";

struct RoundData {
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
}

contract OracleMock is AggregatorV3Interface, Ownable {
    string private constant _description = "Mock Oracle";
    uint8 private immutable _decimals;
    uint256 private immutable _version;
    uint80 private _lastRoundId;
    mapping(uint80 => RoundData) private _roundData;

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);

    /* deciamls = 8, version = 1 */
    constructor(uint8 decimals_, uint256 version_) {
        _decimals = decimals_;
        _version = version_;
    }

    function description() external pure override returns (string memory) {
        return _description;
    }

    function decimals() external view override returns (uint8) {
        return _decimals;
    }

    function version() external view override returns (uint256) {
        return _version;
    }

    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory roundData = _roundData[_roundId];
        return (_roundId, roundData.answer, roundData.startedAt, roundData.updatedAt, roundData.answeredInRound);
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        RoundData memory roundData = _roundData[_lastRoundId];
        return (_lastRoundId, roundData.answer, roundData.startedAt, roundData.updatedAt, roundData.answeredInRound);
    }

    function updateRoundData(RoundData memory roundData) external onlyOwner {
        _lastRoundId++;
        _roundData[_lastRoundId] = roundData;
        emit AnswerUpdated(roundData.answer, _lastRoundId, roundData.updatedAt);
    }
}
