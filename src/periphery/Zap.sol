// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ExternalContractAddresses} from "../library/ExternalContractAddresses.sol";
import {IArbitrageV5} from "../interfaces/IArbitrageV5.sol";
import {ISTUSC} from "../interfaces/ISTUSC.sol";

contract Zap {
    using SafeERC20 for IERC20;

    function zap(address tokenFrom, address tokenTo, uint256 amountIn, address receiver, bytes calldata data)
        external
    {
        IERC20(tokenFrom).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenFrom).approve(ExternalContractAddresses.ONE_INCH_ROUTER, amountIn);

        (bool success,) = ExternalContractAddresses.ONE_INCH_ROUTER.call(data);

        require(success, "Zap: swap failed");

        uint256 amountOut = IERC20(tokenTo).balanceOf(address(this));
        IERC20(tokenTo).safeTransfer(receiver, amountOut);
    }

    function zapMint(
        address arbitrage,
        address tokenFrom,
        address tokenTo,
        uint256 amountIn,
        address receiver,
        bytes calldata data
    ) external {
        IERC20(tokenFrom).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenFrom).forceApprove(ExternalContractAddresses.ONE_INCH_ROUTER, amountIn);

        (bool success,) = ExternalContractAddresses.ONE_INCH_ROUTER.call(data);

        require(success, "Zap: mint failed");

        uint256 amountOut = IERC20(tokenTo).balanceOf(address(this));

        IERC20(tokenTo).approve(arbitrage, amountOut);
        IArbitrageV5(arbitrage).mint(tokenTo, amountOut, receiver);
    }

    function zapMintStake(
        address arbitrage,
        address tokenFrom,
        address tokenTo,
        uint256 amountIn,
        address receiver,
        address staking,
        address usc,
        bytes calldata data
    ) external {
        IERC20(tokenFrom).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenFrom).forceApprove(ExternalContractAddresses.ONE_INCH_ROUTER, amountIn);

        (bool success,) = ExternalContractAddresses.ONE_INCH_ROUTER.call(data);

        require(success, "Zap: mint failed");

        uint256 amountOut = IERC20(tokenTo).balanceOf(address(this));

        IERC20(tokenTo).approve(arbitrage, amountOut);
        IArbitrageV5(arbitrage).mint(tokenTo, amountOut, address(this));

        uint256 mintedUscAmount = IERC20(usc).balanceOf(address(this));

        IERC20(tokenTo).approve(staking, mintedUscAmount);
        ISTUSC(staking).stake(mintedUscAmount, receiver);
    }

    function mintAndStake(
        address arbitrage,
        address token,
        uint256 amount,
        address receiver,
        address staking,
        address usc
    ) external {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        IERC20(token).approve(arbitrage, amount);
        IArbitrageV5(arbitrage).mint(token, amount, address(this));

        uint256 mintedUscAmount = IERC20(usc).balanceOf(address(this));

        IERC20(usc).approve(staking, mintedUscAmount);
        ISTUSC(staking).stake(mintedUscAmount, receiver);
    }

    function mintWithEthAndStake(address arbitrage, address receiver, address staking, address usc) external payable {
        IArbitrageV5(arbitrage).mint{value: msg.value}(address(this));

        uint256 mintedUscAmount = IERC20(usc).balanceOf(address(this));

        IERC20(usc).approve(staking, mintedUscAmount);
        ISTUSC(staking).stake(mintedUscAmount, receiver);
    }

    //TODO: Remove this probably
    receive() external payable {}
}
