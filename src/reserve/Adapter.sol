// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IAdapter.sol";
import "../interfaces/IChainlinkEthAdapter.sol";
import "../interfaces/IPriceFeedAggregator.sol";
import "../library/ExternalContractAddresses.sol";
import "../library/UniswapV2SwapLibrary.sol";
import "../library/UniswapV3SwapLibrary.sol";

abstract contract Adapter is IAdapter, Ownable {
    using SafeERC20 for IERC20;

    IPriceFeedAggregator public immutable priceFeedAggregator;
    address public immutable reserveHolder;
    address public immutable asset;

    Pool public poolType;
    uint256 public totalDeposited;

    modifier onlyReserveHolder() {
        if (msg.sender != reserveHolder) {
            revert NotReserveHolder();
        }
        _;
    }

    constructor(address _reserveHolder, address _priceFeedAggregator, address _asset) Ownable() {
        reserveHolder = _reserveHolder;
        priceFeedAggregator = IPriceFeedAggregator(_priceFeedAggregator);
        asset = _asset;
    }

    /// @inheritdoc IAdapter
    function setPoolType(Pool _poolType) external onlyOwner {
        poolType = _poolType;
        emit SetPoolType(_poolType);
    }

    /// @inheritdoc IAdapter
    function rescueReserves() external onlyOwner {
        IERC20(asset).safeTransfer(msg.sender, IERC20(asset).balanceOf(address(this)));
        totalDeposited = 0;
        emit RescueReserves();
    }

    function rescueToken(address token) external onlyOwner {
        IERC20(token).safeTransfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }
}
