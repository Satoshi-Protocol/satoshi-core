// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* Satoshi Core Address */
address constant SATOSHI_CORE_ADDRESS = 0x365b4915289f2b27dcA58BEBd2960ECDCC2AE3b6;

/* Chainlink Integration Config */
//NOTE: chainlink price feed source address
address constant CHAINLINK_PRICE_FEED_SOURCE_ADDRESS = 0x4c99AD68C293A9de0Cc04B86B6B87AeAFd90F989;

/* DIA Oracle Integration Config */
//NOTE: DIA oracle source address
address constant DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0x9a9a5113b853b394E9BA5FdB7e72bC5797C85191;
uint8 constant DIA_ORACLE_PRICE_FEED_DECIMALS = 8;
string constant DIA_ORACLE_PRICE_FEED_KEY = "BTC/USD";

uint256 constant DIA_MAX_TIME_THRESHOLD = 86400;

/* WSTBTC Integration Config */
address constant WSTBTC_ADDRESS = 0x2967E7Bb9DaA5711Ac332cAF874BD47ef99B3820;
