// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant SATOSHI_CORE_OWNER = 0xB6603E6A4eC100a6eD047C31F429A6e570db9b04;
address constant SATOSHI_CORE_GUARDIAN = 0xB6603E6A4eC100a6eD047C31F429A6e570db9b04;
address constant SATOSHI_CORE_FEE_RECEIVER = 0xB6603E6A4eC100a6eD047C31F429A6e570db9b04;

uint256 constant BO_MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant GAS_COMPENSATION = 2e18; // 2 SAT

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "satUSD";

address constant WETH_ADDRESS = 0xc9864236949C5E7521C5b60FeC9Da5b502e87536;
// bitlayer testnet
// address constant WETH_ADDRESS = 0x3e57d6946f893314324C975AA9CEBBdF3232967E;
// @todo this is core pyth testnet address
address constant PYTH_ADDRESS = 0x8D254a21b3C86D32F7179855531CE99164721933;

//TODO: Replace with the actual timestamp
uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
// OSHI token initial allocation
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant SP_ALLOCATION = 0; // 10,000,000 OSHI (10% of total supply)
