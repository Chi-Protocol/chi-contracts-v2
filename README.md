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
| stUSC                        | `0x6Dd9738FB2277fcD6B2f5eb5FdaAaeC32e702761` | `0x20C70FDF07bC9873f5B67056a76b5c9Cf47Dac93` |
| wstUSC                       | `0xa90f874eB15a13d7a913326Ef41963AaDA9111dd` | `0x6196Dc0d965816E34fEaE12fCB8C8094E72b58f0` |
