// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAdapter {
    enum Pool {
        UNISWAP_V2,
        UNISWAP_V3,
        CURVE,
        LIDO,
        ETHER_FI
    }

    event RescueReserves();
    event SetPoolType(Pool indexed poolType);
    event Deposit(uint256 amount);
    event ClaimRewards(address receiver, uint256 amount);
    event Withdraw(uint256 amount, address recipient);

    error NotReserveHolder();

    /// @notice Gets reserve value in USD
    /// @return reserveValue Reserve value in USD
    function getReserveValue() external view returns (uint256 reserveValue);

    /// @notice Gets total deposited amount
    /// @return totalDeposited Total deposited amount
    function totalDeposited() external view returns (uint256 totalDeposited);

    /// @notice Rescue reserves from contract
    /// @dev Only owner can call this function
    function rescueReserves() external;

    /// @notice Sets pool type
    /// @param _poolType Pool type
    /// @dev Only owner can call this function
    function setPoolType(Pool _poolType) external;

    /// @notice Deposit asset to reserve
    /// @param amount Amount of asset to deposit
    function deposit(uint256 amount) external;

    /// @notice Withdraw asset from reserve
    /// @param amount Amount of asset to withdraw
    /// @param recipient Receiver of asset
    function withdraw(uint256 amount, address recipient) external;

    /// @notice Claim rewards from reserve
    /// @param receiver Receiver of rewards
    /// @return amount Amount of rewards claimed
    function claimRewards(address receiver) external returns (uint256 amount);

    /// @notice Sells LST for ETH when needed for arbitrage or rebalance
    /// @param amountIn Amount of LST to sell
    /// @param minAmountOut Minimum amount of ETH to receive
    /// @param receiver Receiver of ETH
    function swapAmountToEth(uint256 amountIn, uint256 minAmountOut, address receiver) external returns (uint256);

    /// @notice Sells ETH for LST
    /// @param amountIn Amount of ETH to sell
    function swapAmountFromEth(uint256 amountIn) external returns (uint256);
}
