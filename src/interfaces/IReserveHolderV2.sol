// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReserveHolderV2 {
    struct ReserveAssetInfo {
        /// @dev Amount of underlying ETH for this LST
        /// @dev For rebasing tokens it will be equal to amount of LST but for non-rebasing tokens it will depends on exchange rate
        uint256 totalDeposited;
        /// @dev Amount of LST claimed for this LST
        uint256 totalClaimed;
        /// @dev Address of underlying asset, if LST is rebasing then underlying asset is that LST but if LST is non-rebasing then underlying asset is WETH
        address underlyingAsset;
        /// @dev Address of swap adapter for this LST
        address swapAdapter;
        /// @dev Percentage of total reserve tokens that should be kept in this underlying asset
        uint256 percentage;
    }

    event SetArbitrager(address indexed arbitrager, bool enabled);
    event SetClaimer(address indexed claimer);
    event SetRebalancer(address indexed rebalancer, bool enabled);
    event SetSwapTolerance(uint256 swapTolerance);
    event AddReserveAsset(address indexed reserveAsset);
    event SetReserveAssetAdapter(address indexed reserveAsset, address adapter);
    event SetReserveAssetPercentage(address indexed reserveAsset, uint256 percentage);
    event Deposit(address indexed account, address indexed reserveAsset, uint256 amount);
    event Rebalance();
    event Redeem(address indexed account, address indexed reserve, uint256 amount);
    event ClaimRewards(address indexed account);
    event Claimed(address indexed account, address indexed reserveAsset, uint256 amount);

    error NotArbitrager();
    error NotClaimer();
    error NotRebalancer();
    error PercentageTooHigh();
    error AssetAlreadyAdded();
    error SlippageTooBig();

    /// @notice Gets reserve assets
    /// @return reserveAssets Reserve assets
    function getReserveAssets() external view returns (address[] memory reserveAssets);

    /// @notice Updates arbitrager status
    /// @param arbitrager Arbitrager address
    /// @param status Arbitrager status
    function setArbitrager(address arbitrager, bool status) external;

    /// @notice Sets claimer address
    /// @param claimer Claimer address
    /// @custom:usage Claimer should be rewardController contract
    function setClaimer(address claimer) external;

    /// @notice Sets rebalancer address
    /// @param rebalancer Rebalancer address
    /// @param status Rebalancer status
    function setRebalancer(address rebalancer, bool status) external;

    /// @notice Sets swap tolerance
    /// @param swapTolerance Swap tolerance
    /// @dev Only owner can call this function
    function setSwapTolerance(uint256 swapTolerance) external;

    /// @notice Adds reserve asset to reserves
    /// @param reserveAsset Reserve asset address
    /// @param reserveAdapter Adapter address
    /// @param reservePercentage Percentage of reserve asset in reserves
    /// @dev Only owner can call this function
    function addReserveAsset(address reserveAsset, address reserveAdapter, uint256 reservePercentage) external;

    /// @notice Sets adapter for new reserve asset
    /// @param reserveAsset Reserve asset address
    /// @param adapter Adapter address
    /// @dev Only owner can call this function
    function setReserveAssetAdapter(address reserveAsset, address adapter) external;

    /// @notice Sets percentage of reserve asset in reserves
    /// @param reserveAsset Reserve asset address
    /// @param percentage Percentage of reserve asset in reserves
    function setReserveAssetPercentage(address reserveAsset, uint256 percentage) external;

    /// @notice Gets reserve value in USD
    /// @return reserveValue Reserve value in USD
    function getReserveValue() external view returns (uint256 reserveValue);

    /// @notice Deposits reserve asset to reserves
    /// @param reserveAsset Reserve asset address
    /// @param amount Amount of reserve asset to deposit
    function deposit(address reserveAsset, uint256 amount) external;

    /// @notice Rebalance reserve in order to achieve balace
    /// @param spotPrices Spot prices of reserve assets. This is used for slippage protection
    /// @custom:usage This function should be called by external keeper
    function rebalance(uint256[] memory spotPrices) external;

    /// @notice Redeems stETH from reserves
    /// @param amount Amount of stETH to redeem
    /// @param reserve Reserve to redeem
    /// @return wethAmount Amount of WETH received
    /// @custom:usage This function should be called by arbitrage contract
    function redeem(uint256 amount, address reserve) external returns (uint256 wethAmount);

    /// @notice Claims stETH rewards in given amount for given account
    /// @notice Contract does not perform any check and is relying on rewardController contract to perform them
    /// @param account Account to claim stETH rewards for
    /// @custom:usage This function should be called by rewardController contract
    function claimRewards(address account) external;

    /// @notice Swap reserve asset for ETH
    /// @param reserve Reserve asset address
    /// @param amountIn Amount of reserve asset to swap
    /// @param minAmountOut Minimum amount of ETH to receive
    /// @custom:usage This function should be called by arbitrage contract in order to swap reserve asset for ETH and execute arbitrage with ETH
    function swapReserveForEth(address reserve, uint256 amountIn, uint256 minAmountOut) external;
}
