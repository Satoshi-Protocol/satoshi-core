// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

address constant SATOSHI_CORE_OWNER = 0x3AFdDB93D86222669D77d76b50C0C4100454AcAa;
address constant SATOSHI_CORE_GUARDIAN = 0x1B83eC3584e1060f0Ece74F672Aee480df5C5BF1;
address constant SATOSHI_CORE_FEE_RECEIVER = 0x48Af21dB49928a168599451ecC34Bca1B12F5F13;

uint256 constant BO_MIN_NET_DEBT = 100e18; // 100 SAT
uint256 constant GAS_COMPENSATION = 10e18; // 10 SAT

string constant DEBT_TOKEN_NAME = "Satoshi Stablecoin";
string constant DEBT_TOKEN_SYMBOL = "SAT";

address constant WETH_ADDRESS = 0x23a62E7A0b8541b6C217A5a1E750CDb01E954807;
// bitlayer testnet
// address constant WETH_ADDRESS = 0x3e57d6946f893314324C975AA9CEBBdF3232967E;
// @todo this is core pyth testnet address
address constant PYTH_ADDRESS = 0x8D254a21b3C86D32F7179855531CE99164721933;

//TODO: Replace with the actual timestamp
uint32 constant SP_CLAIM_START_TIME = 4294967295; // max uint32
// OSHI token initial allocation
uint256 constant _1_MILLION = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant SP_ALLOCATION = 0; // 10,000,000 OSHI (10% of total supply)
