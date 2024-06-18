// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPSMVault {

    event StrategyAddrSet(address ceffuAddr);
    event PSMAddrSet(address psmAddr);
    event TokenTransferredToStrategy(uint256 amount);
    event TokenTransferredToPSM(uint256 amount);
    event TokenTransferred(address token, address to, uint256 amount);

    function setStrategyAddr(address _strategyAddr) external;
    function setPSMAddr(address _psmAddr) external;
    function transferTokenToPSM(uint256 amount) external;
    function executeStrategy(uint256 amount) external;
    function exitStrategy(uint256 amount) external;
}