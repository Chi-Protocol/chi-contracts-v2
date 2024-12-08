// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ILockingManager} from "../interfaces/ILockingManager.sol";

contract LockingManager is ILockingManager, OwnableUpgradeable {
    struct LockInfo {
        uint256 amount;
        uint256 lockPeriod;
        uint256 startEpoch;
        uint256 endEpoch;
        uint256 lastClaimedEpoch;
    }

    uint256 public constant MIN_LOCK_PERIOD = 1;
    uint256 public constant MAX_LOCK_PERIOD = 365;
    uint256 public constant REWARD_PER_EPOCH_BASE = 1e27;

    bool isPaused;
    IERC20 public lockToken;
    IERC20 public rewardToken;

    uint256 public epochStartTime;
    uint256 public epochDuration;
    uint256 public currentEpoch;
    uint256 public lastUpdatedEpoch;
    uint256 public rewardsPerEpoch;
    uint256 public totalLockedAmount;

    mapping(address => LockInfo[]) public userLocks;
    mapping(uint256 => uint256) public totalTimeWeightedSharesPerEpoch;
    mapping(uint256 => uint256) public totalTimeWeightedSharesUnlockedPerEpoch;
    mapping(address => uint256) public lastClaimedEpoch;
    mapping(uint256 => uint256) public cumulativeRewardsPerEpoch;

    modifier whenNotPaused() {
        if (isPaused) {
            revert Paused();
        }
        _;
    }

    modifier epochStarted() {
        if (block.timestamp < epochStartTime) {
            revert EpochNotStartedYet();
        }
        _;
    }

    function initialize(
        IERC20 _lockToken,
        IERC20 _rewardToken,
        uint256 _epochStartTime,
        uint256 _epochDuration,
        uint256 _initialRewardsPerEpoch
    ) external initializer {
        __Ownable_init();
        lockToken = _lockToken;
        rewardToken = _rewardToken;
        epochStartTime = _epochStartTime;
        epochDuration = _epochDuration;
        currentEpoch = 0;
        rewardsPerEpoch = _initialRewardsPerEpoch;
        lastUpdatedEpoch = 0;
    }

    function userLockingPositions(address user) external view returns (LockInfo[] memory) {
        return userLocks[user];
    }

    function getUserBalance(address user) external view returns (uint256) {
        uint256 balance = 0;
        LockInfo[] memory locks = userLocks[user];

        for (uint256 i = 0; i < locks.length; i++) {
            balance += locks[i].amount;
        }

        return balance;
    }

    function getUserRewards(address user) external view returns (uint256) {
        uint256 rewards = 0;
        LockInfo[] memory locks = userLocks[user];

        for (uint256 i = 0; i < locks.length; i++) {
            rewards += calculateUserRewards(locks[i], locks[i].lastClaimedEpoch + 1, currentEpoch - 1);
        }

        return rewards;
    }

    function getUserRewards(address user, uint256 lockIndex) external view returns (uint256) {
        LockInfo[] memory locks = userLocks[user];

        if (lockIndex >= locks.length) {
            revert InvalidLockIndex();
        }

        return calculateUserRewards(locks[lockIndex], locks[lockIndex].lastClaimedEpoch + 1, currentEpoch - 1);
    }

    function setIsPaused(bool paused) external onlyOwner {
        isPaused = paused;
        emit SetPaused(paused);
    }

    function lock(uint256 amount, uint256 lockPeriod) external epochStarted whenNotPaused {
        _updateEpoch();

        if (lockPeriod < MIN_LOCK_PERIOD || lockPeriod > MAX_LOCK_PERIOD) {
            revert InvalidLockPeriod();
        }

        SafeERC20.safeTransferFrom(IERC20(lockToken), msg.sender, address(this), amount);

        uint256 endEpoch = currentEpoch + lockPeriod;
        LockInfo memory lockInfo = LockInfo({
            amount: amount,
            lockPeriod: lockPeriod,
            startEpoch: currentEpoch + 1,
            endEpoch: endEpoch,
            lastClaimedEpoch: currentEpoch
        });

        userLocks[msg.sender].push(lockInfo);

        uint256 timeWeightedShare = (amount * lockPeriod) / MAX_LOCK_PERIOD;

        totalTimeWeightedSharesPerEpoch[currentEpoch + 1] += timeWeightedShare;
        totalTimeWeightedSharesUnlockedPerEpoch[endEpoch + 1] += timeWeightedShare;

        totalLockedAmount += amount;

        emit LockCreated(msg.sender, amount, lockPeriod);
    }

    function withdraw(uint256 lockIndex) external whenNotPaused epochStarted {
        _updateEpoch();

        LockInfo[] storage locks = userLocks[msg.sender];

        if (lockIndex >= locks.length) {
            revert InvalidLockIndex();
        }

        LockInfo storage lockInfo = locks[lockIndex];

        if (currentEpoch < lockInfo.endEpoch) {
            revert LockPeriodNotOver();
        }

        SafeERC20.safeTransfer(IERC20(lockToken), msg.sender, lockInfo.amount);

        totalLockedAmount -= lockInfo.amount;
        userLocks[msg.sender][lockIndex].amount = 0;

        emit TokensUnlocked(msg.sender, lockInfo.amount, lockInfo.startEpoch, lockInfo.endEpoch);
    }

    function withdrawAllUnlockedPositions() external whenNotPaused epochStarted {
        _updateEpoch();

        uint256 unlockAmount = 0;

        LockInfo[] storage locks = userLocks[msg.sender];

        for (uint256 i = 0; i < locks.length; i++) {
            if (currentEpoch >= locks[i].endEpoch) {
                unlockAmount += locks[i].amount;

                totalLockedAmount -= locks[i].amount;
                userLocks[msg.sender][i].amount = 0;
            }
        }

        SafeERC20.safeTransfer(IERC20(lockToken), msg.sender, unlockAmount);

        emit TokensUnlockedAllPositions(msg.sender, unlockAmount);
    }

    function calculateUserRewards(LockInfo memory userLock, uint256 fromEpoch, uint256 toEpoch)
        internal
        view
        returns (uint256 rewards)
    {
        uint256 userPoints = 0;

        if (userLock.endEpoch >= fromEpoch && userLock.startEpoch <= toEpoch) {
            uint256 lockStart = userLock.startEpoch > fromEpoch ? userLock.startEpoch : fromEpoch;
            uint256 lockEnd = userLock.endEpoch < toEpoch ? userLock.endEpoch : toEpoch;

            for (uint256 epoch = lockStart; epoch <= lockEnd; epoch++) {
                uint256 timeWeightedShare = (userLock.amount * userLock.lockPeriod) / MAX_LOCK_PERIOD;

                if (totalTimeWeightedSharesPerEpoch[epoch] > 0) {
                    userPoints += (timeWeightedShare * REWARD_PER_EPOCH_BASE) / totalTimeWeightedSharesPerEpoch[epoch];
                }
            }

            uint256 totalRewards = (cumulativeRewardsPerEpoch[lockEnd] - cumulativeRewardsPerEpoch[lockStart - 1])
                / (lockEnd - lockStart + 1);
            rewards += (totalRewards * userPoints) / REWARD_PER_EPOCH_BASE;
        }
    }

    function claimRewards() external epochStarted whenNotPaused {
        _updateEpoch();

        uint256 rewards = 0;

        for (uint256 i = 0; i < userLocks[msg.sender].length; i++) {
            uint256 fromEpoch = userLocks[msg.sender][i].lastClaimedEpoch + 1;
            uint256 toEpoch = currentEpoch - 1;

            if (fromEpoch > toEpoch) {
                revert NoRewardsToClaim();
            }

            rewards += calculateUserRewards(userLocks[msg.sender][i], fromEpoch, toEpoch);
            userLocks[msg.sender][i].lastClaimedEpoch = toEpoch;
        }

        rewardToken.transfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, rewards);
    }

    function claimRewards(uint256 lockIndex) external epochStarted whenNotPaused {
        _updateEpoch();

        if (lockIndex >= userLocks[msg.sender].length) {
            revert InvalidLockIndex();
        }

        LockInfo storage lockInfo = userLocks[msg.sender][lockIndex];
        uint256 fromEpoch = lockInfo.lastClaimedEpoch + 1;
        uint256 toEpoch = currentEpoch - 1;

        if (fromEpoch >= toEpoch) {
            revert NoRewardsToClaim();
        }

        uint256 rewards = calculateUserRewards(lockInfo, fromEpoch, toEpoch);
        userLocks[msg.sender][lockIndex].lastClaimedEpoch = toEpoch;

        rewardToken.transfer(msg.sender, rewards);

        emit RewardsClaimed(msg.sender, rewards);
    }

    // when we update rewards per epoch, it will use updated value from next epoch
    // e.g. if we update rewards per epoch at epoch 10, it will use the updated value from epoch 11
    function updateRewardsPerEpoch(uint256 newRewardsPerEpoch) external onlyOwner epochStarted {
        _updateEpoch();

        rewardsPerEpoch = newRewardsPerEpoch;

        emit RewardsPerEpochUpdated(newRewardsPerEpoch);
    }

    function updateEpoch() public epochStarted whenNotPaused {
        _updateEpoch();
    }

    function _updateEpoch() internal {
        uint256 elapsedTime = block.timestamp - epochStartTime;
        uint256 newEpoch = elapsedTime / epochDuration + 1;

        if (newEpoch > currentEpoch) {
            for (uint256 i = currentEpoch + 1; i <= newEpoch; i++) {
                cumulativeRewardsPerEpoch[i] = cumulativeRewardsPerEpoch[i - 1] + rewardsPerEpoch;
                totalTimeWeightedSharesPerEpoch[i] +=
                    totalTimeWeightedSharesPerEpoch[i - 1] - totalTimeWeightedSharesUnlockedPerEpoch[i];
            }
            currentEpoch = newEpoch;

            emit EpochUpdated(currentEpoch);
        }
    }
}
