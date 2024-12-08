// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISTUSC {
    error InsufficientFunds();

    event Stake(address indexed from, address indexed to, uint256 amount);
    event Unstake(address indexed from, address indexed to, uint256 amount);
    event SetEmissionPerSecond(uint256 emissionPerSecond);
    event SetStartTimestamp(uint256 startTimestamp);

    /// @notice Set USC token address
    /// @param usc Address of USC token
    /// @dev Only owner can call this function
    function setUsc(IERC20 usc) external;

    /// @notice Set emission per second
    /// @param _emissionPerSecond Emission per second
    /// @dev Only owner can call this function
    function setEmissionPerSecond(uint256 _emissionPerSecond) external;

    /// @notice Set start timestamp
    /// @param _startTimestamp Start timestamp
    /// @dev Only owner can call this function
    function setStartTimestamp(uint256 _startTimestamp) external;

    /// @notice Stake USC to get stUSC
    /// @param amount Amount of USC to stake
    /// @param recipient Receiver of stUSC
    function stake(uint256 amount, address recipient) external;

    /// @notice Unstake stUSC to get USC
    /// @param amount Amount of stUSC to unstake
    /// @param recipient Receiver of USC
    function unstake(uint256 amount, address recipient) external;
}
