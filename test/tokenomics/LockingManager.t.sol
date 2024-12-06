// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {LockingManager} from "src/tokenomics/LockingManager.sol";
import {ILockingManager} from "src/interfaces/ILockingManager.sol";
import {ERC20Mock} from "../mock/ERC20Mock.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LockingManagerTest is Test {
    LockingManager public lockingManager;
    ERC20Mock public lockToken;
    ERC20Mock public rewardToken;

    address user1 = address(0x123);
    address user2 = address(0x456);
    address owner = address(this);

    uint256 initialRewardPerEpoch = 10 ether;
    uint256 epochDuration = 86400;

    function setUp() public {
        lockToken = new ERC20Mock();
        rewardToken = new ERC20Mock();

        lockingManager = new LockingManager();
        uint256 epochStartTime = block.timestamp + 300 seconds;
        lockingManager.initialize(
            IERC20(address(lockToken)),
            IERC20(address(rewardToken)),
            epochStartTime,
            epochDuration,
            initialRewardPerEpoch
        );

        lockToken.mint(address(this), 1000 ether);
        rewardToken.mint(address(this), 1000 ether);
    }

    function testInitialize() public view {
        assertEq(address(lockingManager.lockToken()), address(lockToken));
        assertEq(address(lockingManager.rewardToken()), address(rewardToken));
        assertEq(lockingManager.rewardsPerEpoch(), initialRewardPerEpoch);
        assertEq(lockingManager.epochDuration(), epochDuration);
    }

    function testUpdateEpoch() public {
        vm.warp(block.timestamp + 2 days);
        lockingManager.updateEpoch();
        assertEq(lockingManager.currentEpoch(), 2);
    }

    function testlock() public {
        lockToken.transfer(user1, 100 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        (uint256 amount, uint256 lockPeriod, uint256 startEpoch,,) = lockingManager.userLocks(user1, 0);
        assertEq(amount, 100 ether);
        assertEq(lockPeriod, 4);
        assertEq(1, lockingManager.currentEpoch());
        assertEq(startEpoch, 2);

        vm.stopPrank();
    }

    function testFuzz_lock(uint256 amount, uint256 lockPeriod) public {
        amount = bound(amount, 1 wei, 1000 ether);
        lockPeriod = bound(lockPeriod, 1, 365);

        lockToken.transfer(user1, amount);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), amount);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(amount, lockPeriod);

        (uint256 _amount, uint256 _lockPeriod, uint256 _startEpoch,,) = lockingManager.userLocks(user1, 0);
        assertEq(_amount, amount);
        assertEq(_lockPeriod, lockPeriod);
        assertEq(1, lockingManager.currentEpoch());
        assertEq(_startEpoch, 2);

        vm.stopPrank();
    }

    function testUnlockAfterLockPeriod() public {
        lockToken.transfer(user1, 100 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        vm.warp(block.timestamp + 5 days);
        lockingManager.withdraw(0);

        assertEq(lockToken.balanceOf(user1), 100 ether);

        vm.stopPrank();
    }

    function testUnlockBeforeLockPeriodEnds_Revert() public {
        lockToken.transfer(user1, 100 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert(ILockingManager.LockPeriodNotOver.selector);
        lockingManager.withdraw(0);

        vm.stopPrank();
    }

    function testUnlockInvalidLockIndex_Revert() public {
        lockToken.transfer(user1, 100 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        vm.warp(block.timestamp + 5 days);

        vm.expectRevert(ILockingManager.InvalidLockIndex.selector);
        lockingManager.withdraw(1);

        vm.stopPrank();
    }

    function testClaimRewards() public {
        rewardToken.transfer(address(lockingManager), 500 ether);
        lockToken.transfer(user1, 100 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        uint256 totalTimeWeightedSharesPerEpoch = lockingManager.totalTimeWeightedSharesPerEpoch(3);
        console.log(totalTimeWeightedSharesPerEpoch);

        vm.startPrank(user1);
        uint256 initialRewardBalance = rewardToken.balanceOf(user1);

        lockingManager.claimRewards();
        totalTimeWeightedSharesPerEpoch = lockingManager.totalTimeWeightedSharesPerEpoch(3);
        console.log(totalTimeWeightedSharesPerEpoch);

        uint256 rewardsClaimed = rewardToken.balanceOf(user1) - initialRewardBalance;
        assertEq(rewardsClaimed, 30 ether);

        vm.stopPrank();
    }

    function testClaimRewardsForMultipleLocks() public {
        rewardToken.transfer(address(lockingManager), 500 ether);
        lockToken.transfer(user1, 150 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 150 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        vm.warp(block.timestamp + 2 days);
        lockingManager.lock(50 ether, 4);

        LockingManager.LockInfo[] memory lockInfo = lockingManager.userLockingPositions(user1);
        console.log(lockInfo[0].amount);
        console.log(lockInfo[1].amount);

        vm.warp(block.timestamp + 3 days);

        uint256 initialRewardBalance = rewardToken.balanceOf(user1);
        lockingManager.claimRewards();
        uint256 rewardsClaimed = rewardToken.balanceOf(user1) - initialRewardBalance;

        assertApproxEqAbs(rewardsClaimed, 40 ether, 1);
        vm.stopPrank();
    }

    function testUpdateRewardsPerEpoch() public {
        vm.warp(block.timestamp + 2 days + 1 seconds);
        lockingManager.updateEpoch();
        assertEq(lockingManager.currentEpoch(), 2);

        lockingManager.updateRewardsPerEpoch(20 ether);

        vm.warp(block.timestamp + 3 days);

        lockingManager.updateEpoch();
        assertEq(lockingManager.cumulativeRewardsPerEpoch(5), 80 ether);
    }

    function testMissedEpochUpdate() public {
        rewardToken.transfer(address(lockingManager), 1000 ether);

        vm.warp(block.timestamp + 4 days);
        lockingManager.updateEpoch();
        assertEq(lockingManager.currentEpoch(), 4);
        assertEq(lockingManager.cumulativeRewardsPerEpoch(4), 40 ether);
    }

    function testMultipleUsers() public {
        rewardToken.transfer(address(lockingManager), 1000 ether);
        lockToken.transfer(user1, 100 ether);
        lockToken.transfer(user2, 50 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.startPrank(user2);
        lockToken.approve(address(lockingManager), 50 ether);
        lockingManager.lock(50 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);
        lockingManager.claimRewards();
        vm.stopPrank();

        assertApproxEqAbs(rewardToken.balanceOf(user1), 20 ether, 10);

        vm.startPrank(user2);
        lockingManager.claimRewards();
        vm.stopPrank();

        assertApproxEqAbs(rewardToken.balanceOf(user2), 10 ether, 10);

        uint256 totalRewards = rewardToken.balanceOf(user1) + rewardToken.balanceOf(user2);
        assertApproxEqAbs(totalRewards, 30 ether, 10);
    }

    function testClaimRewards_SuccessfulClaim() public {
        rewardToken.transfer(address(lockingManager), 500 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);
        uint256 initialRewardBalance = rewardToken.balanceOf(user1);

        lockingManager.claimRewards(0);

        uint256 rewardsClaimed = rewardToken.balanceOf(user1) - initialRewardBalance;
        assertEq(rewardsClaimed, 30 ether);

        vm.stopPrank();
    }

    function testClaimRewards_Revert_InvalidLockIndex() public {
        rewardToken.transfer(address(lockingManager), 500 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);

        vm.expectRevert(ILockingManager.InvalidLockIndex.selector);
        lockingManager.claimRewards(1);

        vm.stopPrank();
    }

    function testClaimRewards_NoNewRewards_Revert() public {
        rewardToken.transfer(address(lockingManager), 500 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);
        lockingManager.claimRewards(0);
        uint256 balanceAfterFirstClaim = rewardToken.balanceOf(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(ILockingManager.NoRewardsToClaim.selector);
        lockingManager.claimRewards(0);

        assertEq(rewardToken.balanceOf(user1), balanceAfterFirstClaim);
        vm.stopPrank();
    }

    function testClaimRewards_MultipleEpochs() public {
        rewardToken.transfer(address(lockingManager), 1000 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 8 days);
        vm.startPrank(user1);
        uint256 initialRewardBalance = rewardToken.balanceOf(user1);

        lockingManager.claimRewards(0);

        uint256 rewardsClaimed = rewardToken.balanceOf(user1) - initialRewardBalance;
        assertEq(rewardsClaimed, 40 ether);

        vm.stopPrank();
    }

    function testClaimRewards_CorrectlyUpdatesLastClaimedEpoch() public {
        rewardToken.transfer(address(lockingManager), 1000 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);

        lockingManager.claimRewards(0);

        uint256 expectedLastClaimedEpoch = lockingManager.currentEpoch() - 1;

        (,,,, uint256 lastClaimedEpoch) = lockingManager.userLocks(user1, 0);
        assertEq(lastClaimedEpoch, expectedLastClaimedEpoch);

        vm.stopPrank();
    }

    function testClaimRewards_ZeroRewardsAvailable() public {
        rewardToken.transfer(address(lockingManager), 1000 ether);
        lockToken.transfer(user1, 100 ether);

        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 100 ether);
        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert(ILockingManager.NoRewardsToClaim.selector);
        lockingManager.claimRewards(0);
        vm.stopPrank();
    }

    function testWithdrawAllUnlockedPositions() public {
        lockToken.transfer(user1, 200 ether);
        vm.startPrank(user1);
        lockToken.approve(address(lockingManager), 200 ether);

        vm.warp(lockingManager.epochStartTime());
        lockingManager.lock(100 ether, 4);

        vm.warp(block.timestamp + 5 days);
        lockingManager.lock(100 ether, 4);
        vm.warp(block.timestamp + 10 days);

        assertEq(lockToken.balanceOf(user1), 0 ether);

        lockingManager.withdrawAllUnlockedPositions();

        assertEq(lockToken.balanceOf(user1), 200 ether);

        vm.stopPrank();
    }
}
