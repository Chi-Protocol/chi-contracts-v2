// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "../interfaces/IPriceFeedAggregator.sol";
import "../interfaces/ISTETH.sol";
import "../interfaces/IWETH.sol";
import "../interfaces/ICurvePool.sol";
import "../interfaces/IReserveHolderV2.sol";
import "../interfaces/IChainlinkEthAdapter.sol";
import "../interfaces/IAdapter.sol";
import "../library/ExternalContractAddresses.sol";

/// @title Contract for holding LST reserves
/// @notice This contract holds LST reserves and rebalances them
/// @notice Part of reserves are is WETH so arbitrage can take them and perform aribtrage without swapping LSTs for WETH
/// @dev This contract is upgradeable
contract ReserveHolderV2 is IReserveHolderV2, OwnableUpgradeable {
    using SafeERC20 for ISTETH;
    using SafeERC20 for IWETH;
    using SafeERC20 for IERC20;

    uint256 public constant BASE_PRICE = 1e8;
    uint256 public constant MAX_PERCENTAGE = 100_00;
    IWETH public constant WETH = IWETH(ExternalContractAddresses.WETH);
    ISTETH public constant stETH = ISTETH(ExternalContractAddresses.stETH);
    ICurvePool public constant curvePool = ICurvePool(ExternalContractAddresses.CURVE_ETH_STETH_POOL);

    IPriceFeedAggregator public priceFeedAggregator;

    address public claimer;
    uint256 public swapTolerance;
    address[] public reserveAssets;

    mapping(address account => bool status) public isArbitrager;
    mapping(address => IAdapter) public reserveAdapters;
    mapping(address => uint256) public percentages;
    mapping(address => bool) public isRebalancer;

    modifier onlyArbitrager() {
        if (isArbitrager[msg.sender] != true) {
            revert NotArbitrager();
        }
        _;
    }

    modifier onlyClaimer() {
        if (msg.sender != claimer) {
            revert NotClaimer();
        }
        _;
    }

    modifier onlyRebalancer() {
        if (isRebalancer[msg.sender] != true) {
            revert NotRebalancer();
        }
        _;
    }

    function initialize(IPriceFeedAggregator _priceFeedAggregator) external initializer {
        __Ownable_init();
        priceFeedAggregator = _priceFeedAggregator;
    }

    /// @inheritdoc IReserveHolderV2
    function getReserveAssets() external view returns (address[] memory) {
        return reserveAssets;
    }

    /// @inheritdoc IReserveHolderV2
    function setArbitrager(address arbitrager, bool status) external onlyOwner {
        isArbitrager[arbitrager] = status;
        emit SetArbitrager(arbitrager, status);
    }

    /// @inheritdoc IReserveHolderV2
    function setClaimer(address _claimer) external onlyOwner {
        claimer = _claimer;
        emit SetClaimer(_claimer);
    }

    /// @inheritdoc IReserveHolderV2
    function setRebalancer(address rebalancer, bool status) external onlyOwner {
        isRebalancer[rebalancer] = status;
        emit SetRebalancer(rebalancer, status);
    }

    /// @inheritdoc IReserveHolderV2
    function setSwapTolerance(uint256 _swapTolerance) external onlyOwner {
        if (_swapTolerance > MAX_PERCENTAGE) {
            revert PercentageTooHigh();
        }

        swapTolerance = _swapTolerance;
        emit SetSwapTolerance(_swapTolerance);
    }

    /// @inheritdoc IReserveHolderV2
    function addReserveAsset(address reserveAsset, address reserveAdapter, uint256 reservePercentage)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < reserveAssets.length; i++) {
            if (reserveAssets[i] == reserveAsset) {
                revert AssetAlreadyAdded();
            }
        }

        reserveAssets.push(reserveAsset);

        setReserveAssetAdapter(reserveAsset, reserveAdapter);
        setReserveAssetPercentage(reserveAsset, reservePercentage);

        emit AddReserveAsset(reserveAsset);
    }

    /// @inheritdoc IReserveHolderV2
    function setReserveAssetAdapter(address reserveAsset, address adapter) public onlyOwner {
        address oldAdapter = address(reserveAdapters[reserveAsset]);

        if (oldAdapter != address(0)) {
            IERC20(reserveAsset).approve(oldAdapter, 0);
            IERC20(WETH).approve(oldAdapter, 0);
        }

        reserveAdapters[reserveAsset] = IAdapter(adapter);

        IERC20(reserveAsset).approve(adapter, type(uint256).max);
        IERC20(WETH).approve(adapter, type(uint256).max);

        emit SetReserveAssetAdapter(reserveAsset, adapter);
    }

    /// @inheritdoc IReserveHolderV2
    function setReserveAssetPercentage(address reserveAsset, uint256 percentage) public onlyOwner {
        if (percentage > MAX_PERCENTAGE) {
            revert PercentageTooHigh();
        }

        percentages[reserveAsset] = percentage;
        emit SetReserveAssetPercentage(reserveAsset, percentage);
    }

    /// @inheritdoc IReserveHolderV2
    function getReserveValue() public view returns (uint256) {
        uint256 wethBalance = WETH.balanceOf(address(this));
        uint256 wethPrice = priceFeedAggregator.peek(ExternalContractAddresses.WETH);
        uint256 totalReserveValue = Math.mulDiv(wethBalance, wethPrice, 1e18);

        for (uint256 i = 0; i < reserveAssets.length; i++) {
            totalReserveValue += reserveAdapters[reserveAssets[i]].getReserveValue();
        }

        return totalReserveValue;
    }

    /// @inheritdoc IReserveHolderV2
    function deposit(address reserveAsset, uint256 amount) external {
        IERC20(reserveAsset).safeTransferFrom(msg.sender, address(this), amount);

        // If address of reserve adapter is 0x0 this means that either token is not supported or it is WETH and we just take it
        // WETH will be calculated in reserves even if it is not in reserveAssets

        if (reserveAsset != address(WETH)) {
            IAdapter reserveAdapter = reserveAdapters[reserveAsset];
            reserveAdapter.deposit(IERC20(reserveAsset).balanceOf(address(this)));
        }

        emit Deposit(msg.sender, reserveAsset, amount);
    }

    /// @inheritdoc IReserveHolderV2
    function rebalance(uint256[] memory protectionParams) external onlyRebalancer {
        _rebalance(protectionParams);
    }

    function rebalance(uint256 minReserveValueAfter) external onlyRebalancer {
        uint256[] memory protectionParams = new uint256[](reserveAssets.length);
        _rebalance(protectionParams);

        if (getReserveValue() < minReserveValueAfter) {
            revert SlippageTooBig();
        }
    }

    function _rebalance(uint256[] memory protectionParams) private {
        uint256 totalReserveValue = getReserveValue();

        // First perform all sells and then buys to make sure we have enough WETH for buys

        for (uint256 i = 0; i < reserveAssets.length; i++) {
            uint256 protectionParam = protectionParams[i];
            address reserveAsset = reserveAssets[i];
            uint256 reserveAssetPercentage = percentages[reserveAsset];

            uint256 reserveAssetTargetValue = Math.mulDiv(totalReserveValue, reserveAssetPercentage, MAX_PERCENTAGE);
            uint256 reserveAssetValue = reserveAdapters[reserveAsset].getReserveValue();
            uint256 minReserveAssetValueForSell =
                Math.mulDiv(reserveAssetTargetValue, MAX_PERCENTAGE + swapTolerance, MAX_PERCENTAGE);

            if (reserveAssetValue > minReserveAssetValueForSell) {
                uint256 reserveAssetValueToSwap = reserveAssetValue - reserveAssetTargetValue;
                uint256 reserveAssetAmountToSwap = Math.mulDiv(
                    reserveAssetValueToSwap, 10 ** IERC20Metadata(reserveAsset).decimals(), _peek(reserveAsset)
                );

                reserveAdapters[reserveAsset].swapAmountToEth(reserveAssetAmountToSwap, protectionParam, address(this));
            }
        }

        for (uint256 i = 0; i < reserveAssets.length; i++) {
            address reserveAsset = reserveAssets[i];
            uint256 reserveAssetPercentage = percentages[reserveAsset];

            uint256 reserveAssetTargetValue = Math.mulDiv(totalReserveValue, reserveAssetPercentage, MAX_PERCENTAGE);
            uint256 reserveAssetValue = reserveAdapters[reserveAsset].getReserveValue();
            uint256 maxReserveAssetValueForBuy =
                Math.mulDiv(reserveAssetTargetValue, MAX_PERCENTAGE - swapTolerance, MAX_PERCENTAGE);

            if (reserveAssetValue < maxReserveAssetValueForBuy) {
                uint256 reserveAssetValueToBuy = reserveAssetTargetValue - reserveAssetValue;
                uint256 ethPrice = priceFeedAggregator.peek(ExternalContractAddresses.WETH);
                uint256 ethAmountToSell = Math.mulDiv(reserveAssetValueToBuy, 1e18, ethPrice);

                IERC20(WETH).approve(address(reserveAdapters[reserveAsset]), ethAmountToSell);
                reserveAdapters[reserveAsset].swapAmountFromEth(ethAmountToSell);
            }
        }

        emit Rebalance();
    }

    /// @inheritdoc IReserveHolderV2
    function redeem(uint256 amount, address reserve) external onlyArbitrager returns (uint256) {
        if (reserve == address(WETH)) {
            WETH.safeTransfer(msg.sender, amount);
        } else {
            reserveAdapters[reserve].withdraw(amount, msg.sender);
        }

        emit Redeem(msg.sender, reserve, amount);
        return amount;
    }

    /// @inheritdoc IReserveHolderV2
    function claimRewards(address account) external onlyClaimer {
        for (uint256 i = 0; i < reserveAssets.length; i++) {
            reserveAdapters[reserveAssets[i]].claimRewards(account);
        }

        emit ClaimRewards(account);
    }

    /// @inheritdoc IReserveHolderV2
    function swapReserveForEth(address reserve, uint256 amountIn, uint256 minAmountOut) external onlyArbitrager {
        reserveAdapters[reserve].swapAmountToEth(amountIn, minAmountOut, address(this));
    }

    function _peek(address asset) private view returns (uint256) {
        uint256 price = priceFeedAggregator.peek(asset);
        return price;
    }
}
