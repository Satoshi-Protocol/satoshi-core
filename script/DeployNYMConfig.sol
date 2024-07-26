pragma solidity ^0.8.13;

address constant ASSET = 0x4F245e278BEC589bAacF36Ba688B412D51874457;
uint256 constant FEE_IN = 25; // 25/10000
uint256 constant FEE_OUT = 250; // 250/10000
uint256 constant MINT_CAP = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant DAILY_MINT_CAP = 10000e18;
address constant PRICE_AGGREGATOR_PROXY = 0xB8954C4e7EBCEEF6F00e3003d5B376A78BF7321F;
bool constant USING_ORACLE = true;
uint256 constant SWAP_WAIT_TIME = 300;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
