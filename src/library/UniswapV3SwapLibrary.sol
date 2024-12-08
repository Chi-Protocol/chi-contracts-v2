// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

library UniswapV3SwapLibrary {
    using SafeERC20 for IERC20;

    ISwapRouter public constant swapRouter = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    function swapExactAmountIn(
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 minAmountOut,
        address receiver
    ) internal returns (uint256) {
        IERC20(assetIn).approve(address(swapRouter), amount);

        return swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: assetIn,
                tokenOut: assetOut,
                fee: 500,
                recipient: receiver,
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: minAmountOut,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function swapExactAmountOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver
    ) internal returns (uint256) {
        IERC20(assetIn).approve(address(swapRouter), maxAmountIn);

        return swapRouter.exactOutputSingle(
            ISwapRouter.ExactOutputSingleParams({
                tokenIn: assetIn,
                tokenOut: assetOut,
                fee: 3000,
                recipient: receiver,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: maxAmountIn,
                sqrtPriceLimitX96: 0
            })
        );
    }
}
