// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ISatoshiCore} from "../interfaces/core/ISatoshiCore.sol";
import {INexusYieldManager} from "../interfaces/core/INexusYieldManager.sol";
import {IVaultManager} from "../interfaces/vault/IVaultManager.sol";
import {IDebtToken} from "../interfaces/core/IDebtToken.sol";
import {INonfungiblePositionManager} from "../interfaces/dependencies/uniswapV3/INonfungiblePositionManager.sol";
import {VaultCore} from "./VaultCore.sol";
import {TickHelper} from "../dependencies/uniswapV3/TickHelper.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UniV3DexVault is VaultCore {
    using SafeERC20 for IERC20;

    enum Option {
        MintPosition,
        AddLiquidity,
        RemoveLiquidity,
        RemoveLiquidityFull,
        CollectFee
    }

    struct Deposit {
        uint128 liquidity;
        address token0;
        address token1;
    }

    INonfungiblePositionManager public nonfungiblePositionManager;
    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;
    uint256[] public tokenIds;

    function initialize(bytes calldata data) external override initializer {
        __UUPSUpgradeable_init_unchained();
        (ISatoshiCore _satoshiCore, address debtToken_, address vaultManager_, address nonfungiblePositionManager_) =
            _decodeInitializeData(data);
        __SatoshiOwnable_init(_satoshiCore);
        debtToken = debtToken_;
        vaultManager = vaultManager_;
        nonfungiblePositionManager = INonfungiblePositionManager(nonfungiblePositionManager_);
    }

    function executeStrategy(bytes calldata data) external override onlyManager {
        Option option = _decodeExecuteData(data);

        if (option == Option.MintPosition) {
            _executeMintPosition(data[32:]);
        } else if (option == Option.AddLiquidity) {
            _executeIncreaseLiquidity(data[32:]);
        } else if (option == Option.RemoveLiquidity) {
            _executeDecreaseLiquidity(data[32:]);
        } else if (option == Option.RemoveLiquidityFull) {
            _executeDecreaseLiquidityFull(data[32:]);
        } else if (option == Option.CollectFee) {
            _executeCollect(data[32:]);
        } else {
            revert InvalidOption(uint256(option));
        }
    }

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function decodeTokenAddress(bytes calldata data) external pure returns (address) {}

    // --- Internal functions ---

    function _decodeInitializeData(bytes calldata data)
        internal
        pure
        returns (ISatoshiCore, address, address, address)
    {
        return abi.decode(data, (ISatoshiCore, address, address, address));
    }

    function _decodeExecuteData(bytes calldata data) internal pure returns (Option) {
        return abi.decode(data, (Option));
    }

    function _decodeExitData(bytes calldata data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }

    function _decodeMintPositionData(bytes memory data)
        internal
        pure
        returns (address, address, uint24, int24, int24, uint256, uint256, uint256, uint256)
    {
        return abi.decode(data, (address, address, uint24, int24, int24, uint256, uint256, uint256, uint256));
    }

    function _decodeIncreaseLiquidityData(bytes memory data)
        internal
        pure
        returns (uint256, uint256, uint256, uint256, uint256)
    {
        return abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
    }

    function _decodeDecreaseLiquidityData(bytes memory data)
        internal
        pure
        returns (uint256, uint128, uint256, uint256)
    {
        return abi.decode(data, (uint256, uint128, uint256, uint256));
    }

    function _decodeDecreaseLiquidityFullData(bytes memory data) internal pure returns (uint256, uint256, uint256) {
        return abi.decode(data, (uint256, uint256, uint256));
    }

    function _decodeCollectData(bytes memory data) internal pure returns (uint256) {
        return abi.decode(data, (uint256));
    }

    function _executeMintPosition(bytes memory data) internal {
        (
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint256 amount0ToMint,
            uint256 amount1ToMint,
            uint256 amount0ToMin,
            uint256 amount1ToMin
        ) = _decodeMintPositionData(data);

        // check which token is token0 and token1
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);

        IERC20(token0).approve(address(nonfungiblePositionManager), amount0ToMint);
        IERC20(token1).approve(address(nonfungiblePositionManager), amount1ToMint);

        bool debtTokenFlag;
        if (token0 == debtToken) debtTokenFlag == true;
        // mint some debtToken
        _mintDebtToken(debtTokenFlag ? amount0ToMint : amount1ToMint);
        // transfer underlyingToken to this contract (from vaultManager)
        address nonDebtToken = debtTokenFlag ? token1 : token0;
        uint256 nonDebtAmount = debtTokenFlag ? amount1ToMint : amount0ToMint;
        IERC20(nonDebtToken).safeTransferFrom(vaultManager, address(this), nonDebtAmount);

        // add liquidity on dex
        (uint256 tokenId,,,) = _mintNewPosition(
            token0, token1, fee, tickLower, tickUpper, amount0ToMint, amount1ToMint, amount0ToMin, amount1ToMin
        );

        // burn any remaining debtToken
        uint256 debtTokenBalance = IDebtToken(debtToken).balanceOf(address(this));
        if (debtTokenBalance != 0) {
            _burnDebtToken(debtTokenBalance);
        }

        _createDeposit(tokenId);
    }

    function _executeIncreaseLiquidity(bytes memory data) internal {
        (uint256 tokenId, uint256 amount0ToMint, uint256 amount1ToMint, uint256 amount0Min, uint256 amount1Min) =
            _decodeIncreaseLiquidityData(data);

        // approve
        IERC20(deposits[tokenId].token0).approve(address(nonfungiblePositionManager), amount0ToMint);
        IERC20(deposits[tokenId].token1).approve(address(nonfungiblePositionManager), amount1ToMint);

        INonfungiblePositionManager.IncreaseLiquidityParams memory params = INonfungiblePositionManager
            .IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: block.timestamp + 1000
        });

        nonfungiblePositionManager.increaseLiquidity(params);

        (,,,,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        // update deposit
        deposits[tokenId].liquidity = liquidity;
    }

    function _executeDecreaseLiquidity(bytes memory data) internal {
        (uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min) =
            _decodeDecreaseLiquidityData(data);
        _decreaseLiquidity(tokenId, liquidity, amount0Min, amount1Min);
    }

    function _executeDecreaseLiquidityFull(bytes memory data) internal {
        (uint256 tokenId, uint256 amount0Min, uint256 amount1Min) = _decodeDecreaseLiquidityFullData(data);
        _decreaseLiquidity(tokenId, deposits[tokenId].liquidity, amount0Min, amount1Min);
    }

    function _executeCollect(bytes memory data) internal {
        uint256 tokenId = _decodeCollectData(data);

        // set amount0Max and amount1Max to uint256.max to collect all fees
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: vaultManager,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(params);

        emit FeeCollected(tokenId, amount0, amount1);
    }

    function _mintNewPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0ToMint,
        uint256 amount1ToMint,
        uint256 amount0ToMintMin,
        uint256 amount1ToMintMin
    ) internal virtual returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        INonfungiblePositionManager.MintParams memory liquidityParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: address(this),
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: amount0ToMintMin,
            amount1Min: amount1ToMintMin,
            deadline: block.timestamp + 1000
        });

        return nonfungiblePositionManager.mint(liquidityParams);
    }

    function _decreaseLiquidity(uint256 tokenId, uint128 liquidity, uint256 amount0Min, uint256 amount1Min) internal {
        if (liquidity == 0) revert ZeroLiquidity();
        if (liquidity > deposits[tokenId].liquidity) revert InvalidLiquidity(liquidity);

        INonfungiblePositionManager.DecreaseLiquidityParams memory params = INonfungiblePositionManager
            .DecreaseLiquidityParams({
            tokenId: tokenId,
            liquidity: liquidity,
            amount0Min: amount0Min,
            amount1Min: amount1Min,
            deadline: block.timestamp + 1000
        });

        nonfungiblePositionManager.decreaseLiquidity(params);
        deposits[tokenId].liquidity -= liquidity;

        // burn the debtToken
        uint256 debtTokenBalance = IDebtToken(debtToken).balanceOf(address(this));
        if (debtTokenBalance != 0) {
            _burnDebtToken(debtTokenBalance);
        }
    }

    function _mintDebtToken(uint256 amount) internal {
        uint256 balanceBefore = IERC20(debtToken).balanceOf(address(this));
        IVaultManager(vaultManager).mintDebtToken(amount);
        uint256 balanceAfter = IERC20(debtToken).balanceOf(address(this));
        uint256 balanceChange = balanceAfter - balanceBefore;
        if (balanceChange != amount) {
            revert DebtTokenBalanceUnexpectedChange(amount, balanceChange);
        }
    }

    function _burnDebtToken(uint256 amount) internal {
        uint256 balanceBefore = IERC20(debtToken).balanceOf(address(this));
        IVaultManager(vaultManager).burnDebtToken(amount);
        uint256 balanceAfter = IERC20(debtToken).balanceOf(address(this));
        uint256 balanceChange = balanceBefore - balanceAfter;
        if (balanceChange != amount) {
            revert DebtTokenBalanceUnexpectedChange(amount, balanceChange);
        }
    }

    function _createDeposit(uint256 tokenId) internal {
        (,, address token0, address token1,,,, uint128 liquidity,,,,) = nonfungiblePositionManager.positions(tokenId);

        deposits[tokenId] = Deposit({liquidity: liquidity, token0: token0, token1: token1});

        _addTokenIdList(tokenId);
        emit createDeposit(tokenId);
    }

    function _addTokenIdList(uint256 tokenId) internal {
        tokenIds.push(tokenId);
        emit TokenIdAdded(tokenId);
    }
}
