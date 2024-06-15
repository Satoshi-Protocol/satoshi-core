// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ICeffuVault {

    event CEFFUAddrSet(address ceffuAddr);
    event PSMAddrSet(address psmAddr);
    event TokenTransferredToCeffu(address token, uint256 amount);
    event TokenTransferredToPSM(address token, uint256 amount);

    function setCEFFUAddr(address _ceffuAddr) external;
    function setPSMAddr(address _psmAddr) external;
    function transferTokenToCeffu(address token, uint256 amount) external;
    function transferTokenToPSM(address token, uint256 amount) external;
}