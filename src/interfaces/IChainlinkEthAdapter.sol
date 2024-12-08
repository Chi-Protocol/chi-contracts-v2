// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IOracle.sol";

interface IChainlinkEthAdapter is IOracle {
    /// @notice Gets exchange rate for ETH from Chainlink price feed
    /// @return rate Exchange rate between underlying asset and ETH
    function exchangeRate() external view returns (uint256 rate);
}
