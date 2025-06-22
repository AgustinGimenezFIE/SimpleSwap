// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/**
 * @title SimpleSwap
 * @notice Implements a simple swap, liquidity provision and pricing system for ERC20 tokens.
 *         No LP token is used; liquidity is tracked internally per user.
 */
contract SimpleSwap {
    struct LiquidityPool {
        uint256 reserveA;                         // Token A reserve
        uint256 reserveB;                         // Token B reserve
        mapping(address => uint256) liquidityShares; // Tracks liquidity shares per user
        uint256 totalLiquidity;                   // Total liquidity in the pool
    }

    // Maps a token pair (hashed) to its liquidity pool
    mapping(bytes32 => LiquidityPool) private pools;

    /**
     * @notice Internal helper to get a unique pool key for a token pair
     * @dev Ensures consistent ordering of token pairs (A < B)
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @return key Hash representing the pool
     */
    function _getPoolKey(address tokenA, address tokenB) private pure returns (bytes32 key) {
        key = tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @notice Add liquidity to a token pair pool
     * @param tokenA Token A address
     * @param tokenB Token B address
     * @param amountADesired Amount of token A the user wants to provide
     * @param amountBDesired Amount of token B the user wants to provide
     * @param amountAMin Minimum amount of A accepted
     * @param amountBMin Minimum amount of B accepted
     * @param to Address to assign liquidity share
     * @param deadline Timestamp after which the transaction expires
     * @return amountA Final token A amount deposited
     * @return amountB Final token B amount deposited
     * @return liquidity Liquidity share added
     */
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        require(block.timestamp <= deadline, "Expired");

        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        amountA = amountADesired;
        amountB = amountBDesired;

        require(amountA >= amountAMin && amountB >= amountBMin, "MinNotMet");

        // Transfer both tokens from sender to contract
        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        // Calculate simple liquidity amount (you could use sqrt or ratio logic)
        liquidity = amountA + amountB;

        // Update reserves and shares
        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.liquidityShares[to] += liquidity;
        pool.totalLiquidity += liquidity;
    }

    /**
     * @notice Remove liquidity and withdraw tokens
     * @param tokenA Token A address
     * @param tokenB Token B address
     * @param liquidity Amount of liquidity to remove
     * @param amountAMin Minimum token A output
     * @param amountBMin Minimum token B output
     * @param to Address receiving the withdrawn tokens
     * @param deadline Timestamp after which transaction expires
     * @return amountA Withdrawn token A amount
     * @return amountB Withdrawn token B amount
     */
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB) {
        require(block.timestamp <= deadline, "Expired");

        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        require(pool.liquidityShares[msg.sender] >= liquidity, "NoLiquidity");

        // Calculate amounts proportionally
        amountA = (liquidity * pool.reserveA) / pool.totalLiquidity;
        amountB = (liquidity * pool.reserveB) / pool.totalLiquidity;

        require(amountA >= amountAMin && amountB >= amountBMin, "MinNotMet");

        // Update pool state
        pool.reserveA -= amountA;
        pool.reserveB -= amountB;
        pool.liquidityShares[msg.sender] -= liquidity;
        pool.totalLiquidity -= liquidity;

        // Transfer back tokens
        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    /**
     * @notice Swap tokens using the constant product formula
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum expected output
     * @param path [tokenIn, tokenOut]
     * @param to Receiver of output tokens
     * @param deadline Transaction expiration timestamp
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(path.length == 2, "PathInvalid");
        require(block.timestamp <= deadline, "Expired");

        bytes32 key = _getPoolKey(path[0], path[1]);
        LiquidityPool storage pool = pools[key];

        // Determine reserves for the direction of the swap
        (uint256 reserveIn, uint256 reserveOut) = path[0] < path[1]
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        // Transfer input tokens
        IERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);

        // Calculate output amount using formula
        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Slippage");

        // Update reserves based on direction
        if (path[0] < path[1]) {
            pool.reserveA += amountIn;
            pool.reserveB -= amountOut;
        } else {
            pool.reserveB += amountIn;
            pool.reserveA -= amountOut;
        }

        // Transfer output tokens to receiver
        IERC20(path[1]).transfer(to, amountOut);
    }

    /**
     * @notice Gets the current exchange rate between tokenA and tokenB
     * @param tokenA Base token
     * @param tokenB Quote token
     * @return price Ratio of tokenB/tokenA (scaled by 1e18)
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        (uint256 reserveA, uint256 reserveB) = tokenA < tokenB
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        require(reserveA > 0, "NoLiquidity");

        // Return price scaled by 1e18
        price = (reserveB * 1e18) / reserveA;
    }

    /**
     * @notice Utility function to compute output amount from swap input
     * @dev Formula: out = (amountIn * reserveOut) / (reserveIn + amountIn)
     * @param amountIn Tokens sent to the pool
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Tokens to be received
     */
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        public
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0 && reserveIn > 0 && reserveOut > 0, "InvalidReserves");
        amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
    }
}
