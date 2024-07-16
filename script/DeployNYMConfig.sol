pragma solidity ^0.8.13;

address constant ASSET = 0x4F245e278BEC589bAacF36Ba688B412D51874457;
uint256 constant FEE_IN = 25; // 25/10000
uint256 constant FEE_OUT = 250; // 250/10000
uint256 constant MINT_CAP = 1e24; // 1e6 * 1e18 = 1e24
uint256 constant DAILY_MINT_CAP = 10000e18;
address constant ORACLE = 0xa790a882bB695D0286C391C0935a05c347290bdB;
bool constant USING_ORACLE = true;
uint256 constant SWAP_WAIT_TIME = 3600;
