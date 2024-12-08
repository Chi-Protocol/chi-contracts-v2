// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IChainlinkEthAdapter.sol";
import "../interfaces/IPriceFeedAggregator.sol";
import "../interfaces/ICurvePool.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ISTETH.sol";
import "./Adapter.sol";

contract StEthAdapter is Adapter {
    using SafeERC20 for IERC20;

    ICurvePool public constant curvePool = ICurvePool(ExternalContractAddresses.CURVE_ETH_STETH_POOL);
    IWETH public constant WETH = IWETH(ExternalContractAddresses.WETH);

    constructor(address _reserveHolder, address _priceFeedAggregator, address _asset)
        Adapter(_reserveHolder, _priceFeedAggregator, _asset)
    {}

    /// @inheritdoc IAdapter
    function getReserveValue() external view override returns (uint256) {
        uint256 assetPrice = priceFeedAggregator.peek(asset);
        return Math.mulDiv(totalDeposited, assetPrice, 10 ** IERC20Metadata(asset).decimals());
    }

    /// @inheritdoc IAdapter
    function deposit(uint256 amount) external {
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));

        amount = balanceAfter - balanceBefore;
        totalDeposited += amount;
        emit Deposit(amount);
    }

    /// @inheritdoc IAdapter
    function withdraw(uint256 amount, address recipient) external onlyReserveHolder {
        IERC20(asset).safeTransfer(recipient, amount);
        totalDeposited -= amount;
        emit Withdraw(amount, recipient);
    }

    /// @inheritdoc IAdapter
    function claimRewards(address receiver) external onlyReserveHolder returns (uint256) {
        uint256 balance = IERC20(asset).balanceOf(address(this));
        uint256 reward = balance - totalDeposited;
        IERC20(asset).safeTransfer(receiver, reward);

        emit ClaimRewards(receiver, reward);
        return reward;
    }

    /// @inheritdoc IAdapter
    function swapAmountToEth(uint256 amountIn, uint256 minAmountOut, address receiver)
        external
        override
        onlyReserveHolder
        returns (uint256)
    {
        IERC20(asset).approve(address(curvePool), amountIn);
        uint256 ethReceived = curvePool.exchange(1, 0, amountIn, minAmountOut);

        totalDeposited -= amountIn;

        WETH.deposit{value: ethReceived}();
        IERC20(WETH).safeTransfer(receiver, ethReceived);

        return ethReceived;
    }

    /// @inheritdoc IAdapter
    function swapAmountFromEth(uint256 amountIn) external onlyReserveHolder returns (uint256) {
        IERC20(WETH).safeTransferFrom(msg.sender, address(this), amountIn);
        IWETH(WETH).withdraw(amountIn);

        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));
        ISTETH(asset).submit{value: amountIn}(address(this));
        uint256 stEthReceived = IERC20(asset).balanceOf(address(this)) - balanceBefore;
        totalDeposited += stEthReceived;

        return stEthReceived;
    }

    receive() external payable {}
}
