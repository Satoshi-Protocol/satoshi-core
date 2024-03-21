// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant SATOSHI_CORE_OWNER = 0xE79c8DBe6D08b85C7B47140C8c10AF5C62678b4a;
address constant SATOSHI_CORE_GUARDIAN = 0x9802b73e7F8BCe57262D537c30521897C07E541C;
address constant SATOSHI_CORE_FEE_RECEIVER = 0x7af1d463627FC62decdEA0826A306eE7660821E8;

uint256 constant BO_MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant GAS_COMPENSATION = 2e18; // 2 SAT

string constant DEBT_TOKEN_NAME = "Statoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "SAT";

address constant WETH_ADDRESS = 0xB5136FEba197f5fF4B765E5b50c74db717796dcD;

//TODO: Replace with the actual timestamp
uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
// OSHI token initial allocation
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant SP_ALLOCATION = 10 * _1_MILLION; // 10,000,000 OSHI (10% of total supply)

//TODO: Replace with the actual timestamp
uint256 constant REFERRAL_START_TIMESTAMP = 1711029600; // Thu Mar 21 2024 14:00:00 GMT+0000
uint256 constant REFERRAL_END_TIMESTAMP = 1717164000; // Fri May 31 2024 14:00:00 GMT+0000
