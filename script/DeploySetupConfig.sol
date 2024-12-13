// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant SATOSHI_CORE_OWNER = 0xbC8709dc1F0B18B8b83aB38D057ED215f90fb42a;
address constant SATOSHI_CORE_GUARDIAN = 0x5a8ee1750F8c5a19506F1649070e71039AE2DEBc;
address constant SATOSHI_CORE_FEE_RECEIVER = 0x5a8ee1750F8c5a19506F1649070e71039AE2DEBc;

uint256 constant BO_MIN_NET_DEBT = 10e18; // 10 SAT
uint256 constant GAS_COMPENSATION = 2e18; // 2 SAT

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "satUSD";

address constant WETH_ADDRESS = 0xda5dDd7270381A7C2717aD10D1c0ecB19e3CDFb2;
// bitlayer testnet
// address constant WETH_ADDRESS = 0x3e57d6946f893314324C975AA9CEBBdF3232967E;
// @todo this is core pyth testnet address
address constant PYTH_ADDRESS = 0x8D254a21b3C86D32F7179855531CE99164721933;

//TODO: Replace with the actual timestamp
uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
// OSHI token initial allocation
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant SP_ALLOCATION = 0; // 10,000,000 OSHI (10% of total supply)
