// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @notice external contract addresses on Ethereum Mainnet
library ExternalContractAddresses {
  address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  address public constant stETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
  address public constant eETH = 0x35fA164735182de50811E8e2E824cFb9B6118ac2;
  address public constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
  address public constant eETH_POOL = 0x308861A430be4cce5502d0A12724771Fc6DaF216;
  address public constant UNI_V2_SWAP_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
  address public constant UNI_V3_SWAP_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
  address public constant UNI_V2_POOL_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
  address public constant ETH_USD_CHAINLINK_FEED = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
  address public constant STETH_USD_CHAINLINK_FEED = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8;
  address public constant WEETH_ETH_CHAINLINK_FEED = 0x5c9C449BbC9a6075A2c061dF312a35fd1E05fF22;
  address public constant CURVE_ETH_STETH_POOL = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022;
  address public constant ONE_INCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;
}
