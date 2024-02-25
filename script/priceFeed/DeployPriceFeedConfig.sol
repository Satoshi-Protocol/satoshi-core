// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* Satoshi Core Address */
address constant SATOSHI_CORE_ADDRESS = 0x0A36f2305e81b9C00FA4b2DfD83E9F6379e8a7C5;

/* Chainlink Integration Config */
//NOTE: chainlink price feed source address
address constant CHAINLINK_PRICE_FEED_SOURCE_ADDRESS = 0x4c99AD68C293A9de0Cc04B86B6B87AeAFd90F989;

/* DIA Oracle Integration Config */
//NOTE: DIA oracle source address
address constant DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0xDfAA53cB0Ce891485389fEBdcD547965906A8300;
uint8 constant DIA_ORACLE_PRICE_FEED_DECIMALS = 8;
string constant DIA_ORACLE_PRICE_FEED_KEY = "BTC/USD";
