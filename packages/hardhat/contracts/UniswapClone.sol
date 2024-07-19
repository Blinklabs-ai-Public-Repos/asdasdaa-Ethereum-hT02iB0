// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract UniswapClone is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Pair {
        IERC20 token0;
        IERC20 token1;
        uint256 reserve0;
        uint256 reserve1;
    }

    mapping(address => mapping(address => Pair)) public pairs;
    mapping(address => bool) public registeredTokens;

    event TokenRegistered(address indexed token);
    event PairCreated(address indexed token0, address indexed token1);
    event Swap(address indexed sender, uint256 amount0In, uint256 amount1In, uint256 amount0Out, uint256 amount1Out);

    /**
     * @dev Registers a new ERC20 token
     * @param token Address of the ERC20 token to register
     */
    function registerToken(address token) external {
        require(!registeredTokens[token], "Token already registered");
        require(IERC20(token).totalSupply() > 0, "Invalid token");

        registeredTokens[token] = true;
        emit TokenRegistered(token);
    }

    /**
     * @dev Creates a new token pair and adds initial liquidity
     * @param tokenA Address of the first token in the pair
     * @param tokenB Address of the second token in the pair
     * @param amountA Amount of tokenA to add as initial liquidity
     * @param amountB Amount of tokenB to add as initial liquidity
     */
    function createPair(address tokenA, address tokenB, uint256 amountA, uint256 amountB) external nonReentrant {
        require(tokenA != tokenB, "Identical addresses");
        require(registeredTokens[tokenA] && registeredTokens[tokenB], "Token not registered");
        require(pairs[tokenA][tokenB].token0 == IERC20(address(0)), "Pair already exists");

        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        (uint256 amount0, uint256 amount1) = tokenA < tokenB ? (amountA, amountB) : (amountB, amountA);

        require(amount0 > 0 && amount1 > 0, "Insufficient liquidity");

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);

        pairs[token0][token1] = Pair(IERC20(token0), IERC20(token1), amount0, amount1);
        pairs[token1][token0] = Pair(IERC20(token0), IERC20(token1), amount0, amount1);

        emit PairCreated(token0, token1);
    }

    /**
     * @dev Swaps tokens
     * @param tokenIn Address of the input token
     * @param tokenOut Address of the output token
     * @param amountIn Amount of input tokens to swap
     * @return amountOut Amount of output tokens received
     */
    function swap(address tokenIn, address tokenOut, uint256 amountIn) external nonReentrant returns (uint256 amountOut) {
        require(amountIn > 0, "Insufficient input amount");
        require(tokenIn != tokenOut, "Invalid token pair");

        Pair storage pair = pairs[tokenIn][tokenOut];
        require(address(pair.token0) != address(0), "Pair does not exist");

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == address(pair.token0) ?
            (pair.reserve0, pair.reserve1) : (pair.reserve1, pair.reserve0);

        uint256 amountInWithFee = amountIn * 997;
        amountOut = (amountInWithFee * reserveOut) / ((reserveIn * 1000) + amountInWithFee);

        require(amountOut > 0, "Insufficient output amount");

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenOut).safeTransfer(msg.sender, amountOut);

        _updateReserves(pair, tokenIn == address(pair.token0) ?
            reserveIn + amountIn : reserveIn,
            tokenOut == address(pair.token1) ?
            reserveOut - amountOut : reserveOut);

        emit Swap(msg.sender, tokenIn == address(pair.token0) ? amountIn : 0, tokenIn == address(pair.token1) ? amountIn : 0,
            tokenOut == address(pair.token0) ? amountOut : 0, tokenOut == address(pair.token1) ? amountOut : 0);

        return amountOut;
    }

    /**
     * @dev Updates the reserves for a pair
     * @param pair The pair to update
     * @param reserve0 New reserve for token0
     * @param reserve1 New reserve for token1
     */
    function _updateReserves(Pair storage pair, uint256 reserve0, uint256 reserve1) private {
        pair.reserve0 = reserve0;
        pair.reserve1 = reserve1;
    }
}