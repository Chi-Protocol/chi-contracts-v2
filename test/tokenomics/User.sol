// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import {IStakingManager} from "src/interfaces/IStakingManager.sol";

contract User is Test {
    ERC20Mock public token;
    ERC20Mock public rewardToken;
    IStakingManager public staking;

    constructor(ERC20Mock _token, ERC20Mock _rewardToken, IStakingManager _staking) {
        token = _token;
        rewardToken = _rewardToken;
        staking = _staking;
    }

    function deposit(uint256 amount) external {
        token.approve(address(staking), amount);
        staking.stake(address(token), amount, address(this));
    }

    function depositRewardToken(uint256 amount) external {
        rewardToken.approve(address(staking), amount);
        staking.stake(address(rewardToken), amount, address(this));
    }

    function withdraw(uint256 amount) external {
        staking.unstake(address(token), amount, address(this));
    }

    function withdrawRewardToken(uint256 amount) external {
        staking.unstake(address(rewardToken), amount, address(this));
    }

    function claimRewards() external {
        staking.claimRewards(address(token), address(this));
    }

    function claimRewardsRewardToken() external {
        staking.claimRewards(address(rewardToken), address(this));
    }

    function transfer(address to, uint256 amount) external {
        IERC20(staking.getStakedToken(address(token))).transfer(to, amount);
    }
}
