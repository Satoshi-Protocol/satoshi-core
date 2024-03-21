// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* Satoshi Core Address */
address constant SATOSHI_CORE_ADDRESS = 0xdF4c52C6be46673210C12262e09f8Ae417E7Beff;

/* Chainlink Integration Config */
//NOTE: chainlink price feed source address
address constant CHAINLINK_PRICE_FEED_SOURCE_ADDRESS = 0x4c99AD68C293A9de0Cc04B86B6B87AeAFd90F989;

/* DIA Oracle Integration Config */
//NOTE: DIA oracle source address
address constant DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0xDfAA53cB0Ce891485389fEBdcD547965906A8300;
uint8 constant DIA_ORACLE_PRICE_FEED_DECIMALS = 8;
string constant DIA_ORACLE_PRICE_FEED_KEY = "BTC/USD";

uint256 constant DIA_MAX_TIME_THRESHOLD = 86400;
