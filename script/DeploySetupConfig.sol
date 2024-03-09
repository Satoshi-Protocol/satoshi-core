// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant SATOSHI_CORE_OWNER = 0x3AFdDB93D86222669D77d76b50C0C4100454AcAa;
address constant SATOSHI_CORE_GUARDIAN = 0x130730818D5C9a2Da5338422C755fcFDf1975147;
address constant SATOSHI_CORE_FEE_RECEIVER = 0x33266D51E5f18d4864d0c04f22252E04c46408f7;

uint256 constant BO_MIN_NET_DEBT = 18e18; // 18 SAT
uint256 constant GAS_COMPENSATION = 2e18; // 2 SAT

string constant DEBT_TOKEN_NAME = "Statoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "SAT";

address constant WETH_ADDRESS = 0x51abb19F1ebc7B64040aFd0ef3C789d75C8707e0;
// OSHI claim start time for Stability Pool
uint32 constant SP_CLAIM_START_TIME = 1709992800;
// OSHI token initial allocation
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant SP_ALLOCATION = 10 * _1_MILLION; // 10,000,000 OSHI (10% of total supply)
