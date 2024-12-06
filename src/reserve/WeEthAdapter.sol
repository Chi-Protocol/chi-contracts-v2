// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/IweETH.sol";
import "../interfaces/IEtherFiLiquidityPool.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IChainlinkEthAdapter.sol";
import "../interfaces/IPriceFeedAggregator.sol";
import "../library/ExternalContractAddresses.sol";
import "../library/UniswapV3SwapLibrary.sol";
import "./Adapter.sol";

contract WeEthAdapter is Adapter {
  using SafeERC20 for IERC20;

  IWETH public constant WETH = IWETH(ExternalContractAddresses.WETH);
  IERC20 public constant eETH = IERC20(ExternalContractAddresses.eETH);

  constructor(
    address _reserveHolder,
    address _priceFeedAggregator,
    address _asset
  ) Adapter(_reserveHolder, _priceFeedAggregator, _asset) {}

  /// @inheritdoc IAdapter
  function getReserveValue() external view override returns (uint256) {
    uint256 assetPrice = priceFeedAggregator.peek(ExternalContractAddresses.WETH);
    return Math.mulDiv(totalDeposited, assetPrice, 1e18);
  }

  /// @inheritdoc IAdapter
  function deposit(uint256 amount) external {
    IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

    IChainlinkEthAdapter chainlinkEthAdapter = IChainlinkEthAdapter(address(priceFeedAggregator.priceFeeds(asset)));
    uint256 assetEthExchangeRate = chainlinkEthAdapter.exchangeRate();

    uint256 amountInEth = Math.mulDiv(amount, assetEthExchangeRate, 10 ** IERC20Metadata(asset).decimals());
    totalDeposited += amountInEth;

    emit Deposit(amount);
  }

  /// @inheritdoc IAdapter
  function withdraw(uint256 amount, address recipient) external onlyReserveHolder {
    IChainlinkEthAdapter chainlinkEthAdapter = IChainlinkEthAdapter(address(priceFeedAggregator.priceFeeds(asset)));
    uint256 assetEthExchangeRate = chainlinkEthAdapter.exchangeRate();

    uint256 amountInEth = Math.mulDiv(amount, assetEthExchangeRate, 10 ** IERC20Metadata(asset).decimals());
    totalDeposited -= amountInEth;

    IERC20(asset).safeTransfer(recipient, amount);

    emit Withdraw(amount, recipient);
  }

  /// @inheritdoc IAdapter
  function claimRewards(address receiver) external onlyReserveHolder returns (uint256) {
    IChainlinkEthAdapter chainlinkEthAdapter = IChainlinkEthAdapter(address(priceFeedAggregator.priceFeeds(asset)));
    uint256 assetEthExchangeRate = chainlinkEthAdapter.exchangeRate();

    uint256 totalBalanceInEthScaled = IERC20(asset).balanceOf(address(this)) * assetEthExchangeRate;
    uint256 totalRewardsInEthScaled = totalBalanceInEthScaled - totalDeposited * 1e18;
    uint256 totalRewardsInAsset = Math.mulDiv(totalRewardsInEthScaled, 1, assetEthExchangeRate);

    IERC20(asset).safeTransfer(receiver, totalRewardsInAsset);

    emit ClaimRewards(receiver, totalRewardsInAsset);
    return totalRewardsInAsset;
  }

  /// @inheritdoc IAdapter
  function swapAmountToEth(
    uint256 amountIn,
    uint256 minAmountOut,
    address receiver
  ) external override onlyReserveHolder returns (uint256) {
    uint256 amountOut = UniswapV3SwapLibrary.swapExactAmountIn(
      asset,
      ExternalContractAddresses.WETH,
      amountIn,
      minAmountOut,
      receiver
    );

    IChainlinkEthAdapter chainlinkEthAdapter = IChainlinkEthAdapter(address(priceFeedAggregator.priceFeeds(asset)));
    uint256 assetEthExchangeRate = chainlinkEthAdapter.exchangeRate();
    totalDeposited -= Math.mulDiv(amountIn, assetEthExchangeRate, 10 ** IERC20Metadata(asset).decimals());

    return amountOut;
  }

  /// @inheritdoc IAdapter
  function swapAmountFromEth(uint256 amountIn) external override onlyReserveHolder returns (uint256) {
    IERC20(WETH).safeTransferFrom(msg.sender, address(this), amountIn);
    IWETH(WETH).withdraw(amountIn);

    IEtherFiLiquidityPool(ExternalContractAddresses.eETH_POOL).deposit{value: amountIn}();
    uint256 eEthReceived = IERC20(eETH).balanceOf(address(this));

    IERC20(eETH).approve(asset, eEthReceived);
    uint256 weEthReceived = IweETH(asset).wrap(eEthReceived);

    IChainlinkEthAdapter chainlinkEthAdapter = IChainlinkEthAdapter(address(priceFeedAggregator.priceFeeds(asset)));
    uint256 assetEthExchangeRate = chainlinkEthAdapter.exchangeRate();
    totalDeposited += Math.mulDiv(weEthReceived, assetEthExchangeRate, 10 ** IERC20Metadata(asset).decimals());

    return weEthReceived;
  }

  receive() external payable {}
}
