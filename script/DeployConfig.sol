// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

address constant PRICE_FEED_ETH_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

address constant PRISMA_CORE_OWNER = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;
address constant PRISMA_CORE_GUARDIAN = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;
address constant PRISMA_CORE_FEE_RECEIVER = 0x6e24f0fF0337edf4af9c67bFf22C402302fc94D3;

uint256 constant BO_MIN_NET_DEBT = 50e18; // 50 SAT
uint256 constant GAS_COMPENSATION = 5e18; // 5 SAT

string constant DEBT_TOKEN_NAME = "Statoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "SAT";
address constant DEBT_TOKEN_LAYER_ZERO_END_POINT = 0x66A71Dcef29A0fFBDBE3c6a460a3B5BC225Cd675;
