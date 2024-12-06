// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "src/interfaces/IOracle.sol";

interface IPriceFeedAggregator {
    event SetPriceFeed(address indexed base, address indexed feed);

    error ZeroAddress();

    /// @notice Sets price feed adapter for given token
    /// @param base Token address
    /// @param feed Price feed adapter address
    function setPriceFeed(address base, address feed) external;

    /// @notice Gets price feed adapter for given token
    /// @param base Token address
    /// @return feed Price feed adapter address
    function priceFeeds(address base) external view returns (IOracle feed);

    /// @notice Gets price for given token
    /// @param base Token address
    /// @return price Price for given token
    function peek(address base) external view returns (uint256 price);
}
