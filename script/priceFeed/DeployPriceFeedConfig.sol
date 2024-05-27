// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/* Satoshi Core Address */
address constant SATOSHI_CORE_ADDRESS = 0xc5De3618aC08D7b278b3c8830cB5Ef3f6aFB8317;

/* Chainlink Integration Config */
//NOTE: chainlink price feed source address
address constant CHAINLINK_PRICE_FEED_SOURCE_ADDRESS = 0x62d2c5dEe038FaEbc3F6ec498fD2Bbb3b0080B03;

/* DIA Oracle Integration Config */
//NOTE: DIA oracle source address
address constant DIA_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0x9a9a5113b853b394E9BA5FdB7e72bC5797C85191;
uint8 constant DIA_ORACLE_PRICE_FEED_DECIMALS = 8;
string constant DIA_ORACLE_PRICE_FEED_KEY = "BTC/USD";

uint256 constant DIA_MAX_TIME_THRESHOLD = 86400;

/* WSTBTC Integration Config */
address constant WSTBTC_ADDRESS = 0x2967E7Bb9DaA5711Ac332cAF874BD47ef99B3820;

/* Pyth Orace Integration Config */
// CORE/USD
address constant PYTH_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0x8D254a21b3C86D32F7179855531CE99164721933;
uint8 constant PYTH_ORACLE_PRICE_FEED_DECIMAL = 8;
bytes32 constant PYTH_ORACLE_PRICEID = 0x9b4503710cc8c53f75c30e6e4fda1a7064680ef2e0ee97acd2e3a7c37b3c830c;

uint256 constant PYTH_MAX_TIME_THRESHOLD = 1200;

/* API3 Oracle Integration Config */
address constant API3_ORACLE_PRICE_FEED_SOURCE_ADDRESS = 0x93050567495E5bA2a30D4592EBbD4EdDa136b893;
uint8 constant API3_ORACLE_PRICE_FEED_DECIMAL = 18;

uint256 constant API3_MAX_TIME_THRESHOLD = 86400;
