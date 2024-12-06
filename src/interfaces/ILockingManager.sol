// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {RewardTokenData, RewardTokenConfig} from "../types/DataTypes.sol";

interface ILockingManager {
  error EpochNotStartedYet();
  error InvalidLockPeriod();
  error NoRewardsToClaim();
  error InvalidLockIndex();
  error LockPeriodNotOver();

  event LockCreated(address indexed user, uint256 amount, uint256 lockPeriod);
  event TokensUnlockedAllPositions(address indexed user, uint256 amount);
  event TokensUnlocked(address indexed user, uint256 amount, uint256 startEpoch, uint256 endEpoch);
  event RewardsClaimed(address indexed user, uint256 amount);
  event EpochUpdated(uint256 newEpoch);
  event RewardsPerEpochUpdated(uint256 newRewardsPerEpoch);

  function lock(uint256 amount, uint256 lockPeriod) external;

  function withdraw(uint256 lockIndex) external;

  function withdrawAllUnlockedPositions() external;

  function claimRewards() external;

  function updateEpoch() external;

  function updateRewardsPerEpoch(uint256 newRewardsPerEpoch) external;

  function getUserBalance(address user) external view returns (uint256);
}
