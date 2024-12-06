// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IEtherFiLiquidityPool {
    function deposit() external payable returns (uint256);
}
