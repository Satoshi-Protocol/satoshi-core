// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

contract DIAOracleV2 {
    mapping(string => uint256) public values;
    address oracleUpdater;

    constructor() {
        oracleUpdater = msg.sender;
    }

    function setValue(string memory key, uint128 value, uint128 timestamp) public {
        require(msg.sender == oracleUpdater);
        uint256 cValue = (((uint256)(value)) << 128) + timestamp;
        values[key] = cValue;
    }

    function getValue(string memory key) external view returns (uint128, uint128) {
        uint256 cValue = values[key];
        uint128 timestamp = (uint128)(cValue % 2 ** 128);
        uint128 value = (uint128)(cValue >> 128);
        return (value, timestamp);
    }
}
