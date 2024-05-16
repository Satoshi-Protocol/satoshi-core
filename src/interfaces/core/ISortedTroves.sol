// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "./ISatoshiCore.sol";
import {ITroveManager} from "./ITroveManager.sol";
import {ISatoshiOwnable} from "../dependencies/ISatoshiOwnable.sol";

// Information for a node in the list
struct Node {
    bool exists;
    address nextId; // Id of next node (smaller NICR) in the list
    address prevId; // Id of previous node (larger NICR) in the list
}

// Information for the list
struct Data {
    address head; // Head of the list. Also the node in the list with the largest NICR
    address tail; // Tail of the list. Also the node in the list with the smallest NICR
    uint256 size; // Current size of the list
    mapping(address => Node) nodes; // Track the corresponding ids for each node in the list
}

interface ISortedTroves is ISatoshiOwnable {
    event NodeAdded(address _id, uint256 _NICR);
    event NodeRemoved(address _id);
    event SetTroveManager(address _troveManager);

    function initialize(ISatoshiCore _satoshiCore) external;

    function insert(address _id, uint256 _NICR, address _prevId, address _nextId) external;

    function reInsert(address _id, uint256 _newNICR, address _prevId, address _nextId) external;

    function remove(address _id) external;

    function setConfig(ITroveManager _troveManager) external;

    function contains(address _id) external view returns (bool);

    function data() external view returns (address head, address tail, uint256 size);

    function findInsertPosition(uint256 _NICR, address _prevId, address _nextId)
        external
        view
        returns (address, address);

    function getFirst() external view returns (address);

    function getLast() external view returns (address);

    function getNext(address _id) external view returns (address);

    function getPrev(address _id) external view returns (address);

    function getSize() external view returns (uint256);

    function isEmpty() external view returns (bool);

    function troveManager() external view returns (ITroveManager);

    function validInsertPosition(uint256 _NICR, address _prevId, address _nextId) external view returns (bool);
}
