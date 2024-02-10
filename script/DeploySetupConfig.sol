// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

//NOTE: custom `PriceFeed.sol` contract should be deploy first
address constant NATIVE_TOKEN_PRICE_FEED = 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165;

address constant SATOSHI_CORE_OWNER = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;
address constant SATOSHI_CORE_GUARDIAN = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;
address constant SATOSHI_CORE_FEE_RECEIVER = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;

uint256 constant BO_MIN_NET_DEBT = 50e18; // 50 SAT
uint256 constant GAS_COMPENSATION = 5e18; // 5 SAT

string constant DEBT_TOKEN_NAME = "Statoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "SAT";
