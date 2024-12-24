# Chi Protocol V2

This repository contains the smart contracts source code for Chi Protocol. This repository uses both Hardhat and Foundry development environment for compilation, Foundry for testing and Hardhat for deployment.

## What is Chi Protocol?

Chi is an Ethereum-based protocol issuing a decentralized and capital-efficient stablecoin, known as USC, designed to bring stability, scalability and greater economic incentives to the world of decentralized finance. USC is the first stablecoin issued by Chi Protocol. LSTs are used as collateral to back it, and it relies on a dual stability mechanism to maintain the price at $1.

## Documentation

See the link to the whitepaper or visit official Chi docs

- https://chi-protocol.gitbook.io/docs/background/chi-protocol
- https://docsend.com/view/3vz6us5vca98kmvs

## Contract addresses

| Contract                     | Proxy address                                | Implementation address                       |
| ---------------------------- | -------------------------------------------- | -------------------------------------------- |
| USC                          |                                              | `0x38547D918b9645F2D94336B6b61AEB08053E142c` |
| CHI                          |                                              | `0x3b21418081528845a6DF4e970bD2185545b712ba` |
| StakingManager               | `0x1402452D1FF1066AcB48Aa2d5E4c0Ca81a8a6B16` | `0x3881d1aAfbc7C519aE7D65177365db9bc283b75D` |
| StakedToken                  |                                              | `0xF40A7f75c0E5CF5FEfD56c40fDF494b58dAE5668` |
| StakedToken (stUSC/ETH LP)   | `0x044bCdf7deA1a825B7be24573b738462a4FE9D3f` | `0xF40A7f75c0E5CF5FEfD56c40fDF494b58dAE5668` |
| StakedToken (stCHI/ETH LP)   | `0x8f3871fD26Ac117f6E3D55E5f98E627Ca5d5e581` | `0xF40A7f75c0E5CF5FEfD56c40fDF494b58dAE5668` |
| stUSC/ETH LP Locking Manager | `0x06Ad9F7DCF8DB10B1a39168e32ace2425a1F88aE` | `0xb8aff422aE47A9074271cfc14689EFfF2d4Ac10c` |
| stCHI/ETH LP Locking Manager | `0x371a13Db03e929944AD61530F5bfc7a86cF98ff5` | `0x40C53DFb3657a9375905e5d5E52235F259736331` |
| wstUSC Locking Manager       | `0x96F3258e9c15EA33C82cd062220634df7Fb096B1` | `0xF602Cbb6b4fEDDc15b5455b6f9927f804A48B065` |
| stUSC                        | `0x6Dd9738FB2277fcD6B2f5eb5FdaAaeC32e702761` | `0x8bbe0218945f3EcA6EB0A9D6474f678e4e4C91d6` |
| wstUSC                       | `0xb7343ADda6b97BB1dE39b8d9dF2630cFBb963871` | `0x97FdEeC510B5fB34B675D13196af0F8313730ba2` |
| Arbitrage                    | ``                                           | `0x594f4983Df88c3d84caA6eb30C18fBA1986ED6f1` |
| PriceFeedAggregator          | ``                                           | `0xb3a36232ECc1da6C8D0d3f417E00406566933bD0` |
| weETH Oracle                 | ``                                           | `0x6b06E6C2F8c498835fab196eadDdE53d3D103C59` |
| ReserveHolderV2              | `0xc36303ef9c780292755B5a9593Bfa8c1a7817E2a` | `0x6b944e7903d05e0396Cfc263A5f563e93d84A3f5` |
| stETH Adapter                | ``                                           | `0x18601d46c38362cDA8CA0571BbBCD9a34bC2BD65` |
| weETH Adapter                | ``                                           | `0x7f6dA7071d3524C61c2c87c4e631E52cbC8af5b6` |
| DataProvider                 |                                              | `0x1A387041Aa6660cD801B5c96AA1B4028a7d26Bd1` |
| ReserveHolderDataProvider    |                                              | `0x72Fe0f6402eC84f2156f979c1b256F67B5A8B356` |
| Zap                          |                                              | `0xD4cc670e076B6963882aFE63FF6142cBcbC156F9` |
