// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title SimpleSwap
 * @notice A basic token swap contract using the constant product formula.
 * @dev Liquidity is tracked internally. No LP tokens are issued.
 */
contract SimpleSwap {
    /// @notice Represents a liquidity pool for a token pair
    struct LiquidityPool {
        uint256 reserveA;
        uint256 reserveB;
        mapping(address => uint256) liquidityShares;
        uint256 totalLiquidity;
    }

    /// @notice Maps token pair hash to liquidity pool
    mapping(bytes32 => LiquidityPool) private pools;

    /**
     * @notice Internal function to compute a unique key for a token pair
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @return key Unique identifier for the pool
     */
    function _getPoolKey(address tokenA, address tokenB) private pure returns (bytes32 key) {
        key = tokenA < tokenB
            ? keccak256(abi.encodePacked(tokenA, tokenB))
            : keccak256(abi.encodePacked(tokenB, tokenA));
    }

    /**
     * @notice Add liquidity to a token pair pool
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param amountADesired Amount of token A to deposit
     * @param amountBDesired Amount of token B to deposit
     * @param amountAMin Minimum token A to accept
     * @param amountBMin Minimum token B to accept
     * @param to Address receiving liquidity shares
     * @param deadline Unix timestamp after which tx is rejected
     * @return amountA Actual token A deposited
     * @return amountB Actual token B deposited
     * @return liquidity Liquidity shares received
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

        pool.reserveA += amountA;
        pool.reserveB += amountB;
        pool.liquidityShares[to] += liquidity;
        pool.totalLiquidity += liquidity;
    }

    /**
     * @notice Remove liquidity and withdraw tokens
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @param liquidity Amount of liquidity to remove
     * @param amountAMin Minimum token A to receive
     * @param amountBMin Minimum token B to receive
     * @param to Address receiving tokens
     * @param deadline Unix timestamp after which tx is rejected
     * @return amountA Token A amount returned
     * @return amountB Token B amount returned
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

        pool.reserveA = reserveA - amountA;
        pool.reserveB = reserveB - amountB;
        pool.liquidityShares[msg.sender] = userShare - liquidity;
        pool.totalLiquidity = totalLiq - liquidity;

        IERC20(tokenA).transfer(to, amountA);
        IERC20(tokenB).transfer(to, amountB);
    }

    /**
     * @notice Swap tokenIn for tokenOut
     * @param amountIn Amount of input token
     * @param amountOutMin Minimum output token to receive
     * @param path Array: [tokenIn, tokenOut]
     * @param to Receiver of output token
     * @param deadline Unix timestamp after which tx is rejected
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

        uint256 reserveIn;
        uint256 reserveOut;

        if (tokenIn < tokenOut) {
            reserveIn = pool.reserveA;
            reserveOut = pool.reserveB;
        } else {
            reserveIn = pool.reserveB;
            reserveOut = pool.reserveA;
        }

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Slippage");

        if (tokenIn < tokenOut) {
            pool.reserveA = reserveIn + amountIn;
            pool.reserveB = reserveOut - amountOut;
        } else {
            pool.reserveB = reserveIn + amountIn;
            pool.reserveA = reserveOut - amountOut;
        }

        IERC20(tokenOut).transfer(to, amountOut);
    }

    /**
     * @notice Returns price of tokenB per tokenA
     * @param tokenA Base token
     * @param tokenB Quote token
     * @return price Price scaled by 1e18
     */
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        bytes32 key = _getPoolKey(tokenA, tokenB);
        LiquidityPool storage pool = pools[key];

        uint256 reserveA = tokenA < tokenB ? pool.reserveA : pool.reserveB;
        uint256 reserveB = tokenA < tokenB ? pool.reserveB : pool.reserveA;

        require(reserveA > 0, "NoLiquidity");
        price = (reserveB * 1e18) / reserveA;
    }

    /**
     * @notice Calculates output tokens for a given input
     * @dev Pure function, can be called off-chain
     * @param amountIn Input token amount
     * @param reserveIn Reserve of input token
     * @param reserveOut Reserve of output token
     * @return amountOut Output token amount
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
