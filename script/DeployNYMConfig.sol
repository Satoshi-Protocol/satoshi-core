pragma solidity ^0.8.13;

address constant DEBT_TOKEN_ADDRESS = 0x78Fea795cBFcC5fFD6Fb5B845a4f53d25C283bDB;
address constant SATOSHI_CORE_ADDRESS = 0xd6dBF24f3516844b02Ad8d7DaC9656F2EC556639;
address constant REWARD_MANAGER_PROXY_ADDRESS = 0x1E4DC3B9963365760e2048AD05eE6f11Dc287c0B;

// Asset config
address constant ASSET = 0x05D032ac25d322df992303dCa074EE7392C117b9;
uint256 constant FEE_IN = 5; // 5/10000 (0.05%)
uint256 constant FEE_OUT = 50; // 50/10000 (0.5%)
uint256 constant MINT_CAP = 10 * 1e24; // 1e6 * 1e18 = 1e24 (10 million)
uint256 constant DAILY_MINT_CAP = 1e24; // 1e6 * 1e18 = 1e24 (1 million)
address constant PRICE_AGGREGATOR_PROXY = 0x665126290A2FE0E77277E07eaC59fd760662a1d6;
bool constant USING_ORACLE = true;
uint256 constant SWAP_WAIT_TIME = 3 days;
uint256 constant MAX_PRICE = 1.05e18; // 1e18
uint256 constant MIN_PRICE = 0.95e18; // 1e18
