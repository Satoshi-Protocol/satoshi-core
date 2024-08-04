pragma solidity ^0.8.13;

address constant DEBT_TOKEN_ADDRESS = 0xa1e63CB2CE698CfD3c2Ac6704813e3b870FEDADf;
address constant SATOSHI_CORE_ADDRESS = 0x6401446A7f9989158F8BD65aeed43332eeFd5216;
address constant REWARD_MANAGER_PROXY_ADDRESS = 0xfc8ab0e486F17c78Eaf59A416168d0F89D9373eD;
address constant NYM_ADDRESS = 0xC562321a494290bE5FeDF9092cee35DE6f884D50;

address constant ASSET = 0x9827431e8b77E87C9894BD50B055D6BE56bE0030;
uint256 constant FEE_IN = 5; // 5/10000 (0.05%)
uint256 constant FEE_OUT = 50; // 50/10000 (0.5%)
uint256 constant MINT_CAP = 10 * 1e24; // 1e6 * 1e18 = 1e24 (10 million)
uint256 constant DAILY_MINT_CAP = 1e24; // 1e6 * 1e18 = 1e24 (1 million)
address constant PRICE_AGGREGATOR_PROXY = 0xB7DeeFa4e0f8bEa85421f0acee38a33E8C2E00d5;
bool constant USING_ORACLE = true;
uint256 constant SWAP_WAIT_TIME = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
