// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "src/library/ExternalContractAddresses.sol";

library UniswapV2SwapLibrary {
    IUniswapV2Router02 public constant swapRouter = IUniswapV2Router02(ExternalContractAddresses.UNI_V2_SWAP_ROUTER);

    function swapExactAmountIn(
        address assetIn,
        address assetOut,
        uint256 amount,
        uint256 minAmountOut,
        address receiver
    ) external returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = assetIn;
        path[1] = assetOut;
        IERC20(assetIn).approve(address(swapRouter), amount);

        uint256[] memory amounts =
            swapRouter.swapExactTokensForTokens(amount, minAmountOut, path, receiver, block.timestamp);

        return amounts[1];
    }

    function swapExactAmountOut(
        address assetIn,
        address assetOut,
        uint256 amountOut,
        uint256 maxAmountIn,
        address receiver
    ) external returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = assetIn;
        path[1] = assetOut;
        IERC20(assetIn).approve(address(swapRouter), maxAmountIn);

        uint256[] memory amounts =
            swapRouter.swapTokensForExactTokens(amountOut, maxAmountIn, path, receiver, block.timestamp);

        return amounts[0];
    }
}
