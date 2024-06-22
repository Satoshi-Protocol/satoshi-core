// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ISatoshiCore} from "../core/ISatoshiCore.sol";

interface INYMVault {
    event StrategyAddrSet(address ceffuAddr);
    event NYMAddrSet(address psmAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToNYM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);

    function setStrategyAddr(address _strategyAddr) external;
    function setNYMAddr(address _nymAddr) external;
    function transferTokenToNYM(uint256 amount) external;
    function executeStrategy(uint256 amount) external;
    function exitStrategy(uint256 amount) external;
    function initialize(ISatoshiCore _satoshiCore, address stableTokenAddress_) external;
}
