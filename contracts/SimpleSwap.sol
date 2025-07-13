// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleSwap
 * @notice A basic token swap contract using the constant product formula.
 * @dev Liquidity is tracked internally. No LP tokens are issued.
 */
contract SimpleSwap {
    /// @notice Represents the state of a liquidity pool for a token pair
    struct LiquidityPool {
        uint256 reserveA;                    ///< Amount of token A in the pool
        uint256 reserveB;                    ///< Amount of token B in the pool
        mapping(address => uint256) liquidityShares; ///< Mapping of user address to liquidity share
        uint256 totalLiquidity;              ///< Total liquidity added to the pool
    }

    /// @notice Mapping from pool key to its corresponding LiquidityPool
    mapping(bytes32 => LiquidityPool) private pools;

    /**
     * @notice Generates a unique identifier for a token pair
     * @dev Token order is normalized to ensure consistent pool mapping
     * @param tokenA Address of the first token
     * @param tokenB Address of the second token
     * @return key The unique identifier for the token pair
     */
    function _getPoolKey(address tokenA, address tokenB) private pure returns (bytes32 key) {
        key = tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @notice Adds liquidity to the pool for a given token pair
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param amountADesired Desired amount of token A to deposit
     * @param amountBDesired Desired amount of token B to deposit
     * @param amountAMin Minimum amount of token A to accept
     * @param amountBMin Minimum amount of token B to accept
     * @param to Address receiving the liquidity share
     * @param deadline Unix timestamp after which the transaction is rejected
     * @return amountA Actual amount of token A deposited
     * @return amountB Actual amount of token B deposited
     * @return liquidity Total liquidity credited to the user
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

        amountA = amountADesired;
        amountB = amountBDesired;

        require(amountA >= amountAMin && amountB >= amountBMin, "MinNotMet");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        liquidity = amountA + amountB;

        unchecked {
            pool.reserveA += amountA;
            pool.reserveB += amountB;
            pool.liquidityShares[to] += liquidity;
            pool.totalLiquidity += liquidity;
        }
    }

    /**
     * @notice Removes liquidity from a token pair pool
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param liquidity Amount of liquidity to remove
     * @param amountAMin Minimum amount of token A to receive
     * @param amountBMin Minimum amount of token B to receive
     * @param to Address to receive the withdrawn tokens
     * @param deadline Unix timestamp after which the transaction is rejected
     * @return amountA Amount of token A returned to the user
     * @return amountB Amount of token B returned to the user
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

        uint256 userShare = pool.liquidityShares[msg.sender];
        uint256 totalLiq = pool.totalLiquidity;
        require(userShare >= liquidity && totalLiq > 0, "NoLiquidity");

        uint256 reserveA = pool.reserveA;
        uint256 reserveB = pool.reserveB;

        amountA = (liquidity * reserveA) / totalLiq;
        amountB = (liquidity * reserveB) / totalLiq;

        require(amountA >= amountAMin && amountB >= amountBMin, "MinNotMet");

        unchecked {
            pool.reserveA = reserveA - amountA;
            pool.reserveB = reserveB - amountB;
            pool.liquidityShares[msg.sender] = userShare - liquidity;
            pool.totalLiquidity = totalLiq - liquidity;
        }

        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    /**
     * @notice Executes a token swap between two tokens using a fixed input amount
     * @param amountIn Amount of input token to swap
     * @param amountOutMin Minimum acceptable output token amount
     * @param path Array of two addresses: [inputToken, outputToken]
     * @param to Recipient address of the output token
     * @param deadline Unix timestamp after which the transaction is rejected
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

        address tokenIn = path[0];
        address tokenOut = path[1];

        bytes32 key = _getPoolKey(tokenIn, tokenOut);
        LiquidityPool storage pool = pools[key];

        (uint256 reserveIn, uint256 reserveOut) = tokenIn < tokenOut
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        require(amountOut >= amountOutMin, "Slippage");

        unchecked {
            if (tokenIn < tokenOut) {
                pool.reserveA = reserveIn + amountIn;
                pool.reserveB = reserveOut - amountOut;
            } else {
                pool.reserveB = reserveIn + amountIn;
                pool.reserveA = reserveOut - amountOut;
            }
        }

        IERC20(tokenOut).transfer(to, amountOut);
    }

    /**
     * @notice Returns the current exchange rate for a token pair
     * @param tokenA Address of the base token
     * @param tokenB Address of the quote token
     * @return price Current price of tokenB per tokenA, scaled by 1e18
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        (uint256 reserveA, uint256 reserveB) = tokenA < tokenB
            ? (pool.reserveA, pool.reserveB)
            : (pool.reserveB, pool.reserveA);

        require(reserveA > 0, "NoLiquidity");

        price = (reserveB * 1e18) / reserveA;
    }
}
