// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title An immutable proxy contract that is used to read a specific data
/// feed (Beacon or Beacon set) of a specific Api3ServerV1 contract
/// @notice In an effort to reduce the bytecode of this contract, its
/// constructor arguments are validated by ProxyFactory, rather than
/// internally. If you intend to deploy this contract without using
/// ProxyFactory, you are recommended to implement an equivalent validation.
/// @dev See DapiProxy.sol for comments about usage
contract DataFeedProxy {

    int224 internal value;
    uint32 internal timestamp;

    constructor() {}

    function updatePrice(int224 _price) external {
        value = _price;
        timestamp = uint32(block.timestamp);
    }

    /// @notice Reads the data feed that this proxy maps to
    /// @return value Data feed value
    /// @return timestamp Data feed timestamp
    function read()
        external
        view
        returns (int224, uint32)
    {
        return (value, timestamp);
    }
}