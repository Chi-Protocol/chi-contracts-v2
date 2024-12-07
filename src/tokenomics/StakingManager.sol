// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IStakingManager} from "../interfaces/IStakingManager.sol";
import {ILockingManager} from "../interfaces/ILockingManager.sol";
import {RewardTokenData, RewardTokenConfig} from "../types/DataTypes.sol";
import {StakedToken} from "./StakedToken.sol";
import {IStakedToken} from "../interfaces/IStakedToken.sol";
import {StakedTokenBeaconProxy} from "./StakedTokenBeaconProxy.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @title StakingManger contract
/// @notice Contract for staking tokens and earning multiple tokens as rewards
/// @dev One contract handles multiple staking tokens and multiple reward tokens for each staking token
contract StakingManager is IStakingManager, OwnableUpgradeable {
    /// @dev Constant that determines on how many decimals rewardPerStakedToken will be calculated and saved in storage
    /// @dev The more decimals this value has the more precision rewards will have
    /// @dev Nothing more than changing this value is needed in order to change precision
    uint256 public constant REWARD_PER_STAKED_TOKEN_BASE = 1e18;

    struct TokenInfo {
        /// @dev Address of staked token smart contract that is ERC20 representation of position in the pool
        /// @dev Staking tokens are hold in Staking smart contract
        /// @dev StakedToken is minted when user deposits tokens and burned when user withdraws tokens, user can transfer StakedToken to other users
        /// @dev If stakedToken is not zero address this means that staking token has already been whitelisted
        address stakedToken;
        /// @dev Address of LockingManager contract that is used for locking tokens
        /// @dev LockingManager contract is used for locking tokens, user can lock tokens for certain period of time and earn rewards
        ILockingManager lockingManager;
        /// @dev List of reward tokens, rewards are distributed for each token in the list
        /// @dev When new reward token is added, it is appended to the list, but it is not removed when reward token is removed
        address[] rewardTokens;
        /// @dev Data for each reward token, reward per staked token and last updated timestamp
        /// @dev This data is used to calculate rewards for each user and is updated on each interaction with the contract
        /// @dev Reward token address => reward token data
        mapping(address => RewardTokenData) rewardTokenData;
        /// @dev Emission per second for each reward token
        /// @dev Reward token address => emission per second
        mapping(address => RewardTokenConfig) rewardTokenConfig;
        /// @dev Reward debt for each user and reward token
        /// @dev Reward debt is used when calculating rewards for user, logic is copied from MasterChef contract
        /// @dev Reward debt is calculated on each interaction with the contract
        /// @dev Account => reward token => reward debt
        mapping(address => mapping(address => uint256)) rewardDebt;
        /// @dev Accrued rewards for each user and reward token, accrued rewards are not total rewards but only rewards that user had at the time of last interaction with the contract
        /// @dev Accrued rewards are calculated on each interaction with the contract, when user claims rewards accrued rewards are set to 0
        /// @dev MasterChef contract sends rewards to user on each interaction, but this contract does not send rewards to user, user must claim rewards
        /// @dev Account => reward token => accrued rewards
        mapping(address => mapping(address => uint256)) accruedRewards;
    }

    /// @dev True if contract is paused, false otherwise
    bool isPaused;

    /// @dev Address of implementation contract for StakedToken smart contract
    /// @dev When this address is changed all StakedToken contract are automatically upgraded since they are BeaconProxy
    address stakedTokenImplementation;

    /// @dev Mapping of token info for each staking token
    mapping(address => TokenInfo) tokenInfo;

    /// @dev Array of staking tokens, used to iterate over all staking tokens
    address[] stakingTokens;

    modifier whenNotPaused() {
        if (isPaused) {
            revert Paused();
        }
        _;
    }

    modifier onlyActiveStaking(address asset) {
        if (!isStakingStarted(asset)) {
            revert StakingNotStarted();
        }
        _;
    }

    modifier onlyStakedToken(address stakingToken) {
        if (msg.sender != getStakedToken(stakingToken)) {
            revert NotStakedToken();
        }
        _;
    }

    function initialize() external initializer {
        __Ownable_init();
    }

    /// @inheritdoc IStakingManager
    function getIsPaused() external view returns (bool) {
        return isPaused;
    }

    /// @inheritdoc IStakingManager
    function getStakedTokenImplementation() external view returns (address) {
        return stakedTokenImplementation;
    }

    /// @inheritdoc IStakingManager
    function getStakedToken(address stakingToken) public view returns (address) {
        return tokenInfo[stakingToken].stakedToken;
    }

    /// @inheritdoc IStakingManager
    function isStakingStarted(address asset) public view returns (bool) {
        return tokenInfo[asset].stakedToken != address(0);
    }

    /// @inheritdoc IStakingManager
    function getStakingTokens() external view returns (address[] memory) {
        return stakingTokens;
    }

    /// @inheritdoc IStakingManager
    function getRewardTokens(address stakingToken) external view returns (address[] memory) {
        return tokenInfo[stakingToken].rewardTokens;
    }

    /// @inheritdoc IStakingManager
    function getRewardTokenConfig(address stakingToken, address rewardToken)
        external
        view
        returns (RewardTokenConfig memory rewardTokenConfig)
    {
        return tokenInfo[stakingToken].rewardTokenConfig[rewardToken];
    }

    /// @inheritdoc IStakingManager
    function getRewardTokenData(address stakingToken, address rewardToken)
        external
        view
        returns (RewardTokenData memory rewardTokenData)
    {
        return tokenInfo[stakingToken].rewardTokenData[rewardToken];
    }

    /// @inheritdoc IStakingManager
    function getTotalStaked(address stakingToken) public view returns (uint256) {
        return IERC20(tokenInfo[stakingToken].stakedToken).totalSupply();
    }

    /// @inheritdoc IStakingManager
    function getUserBalanceOnLockingManager(address user, address stakingToken) public view returns (uint256) {
        ILockingManager lockingManager = tokenInfo[stakingToken].lockingManager;
        return address(lockingManager) != address(0) ? lockingManager.getUserBalance(user) : 0;
    }

    /// @inheritdoc IStakingManager
    function getUserStakedBalance(address user, address stakingToken) public view returns (uint256) {
        return IERC20(tokenInfo[stakingToken].stakedToken).balanceOf(user)
            + getUserBalanceOnLockingManager(user, stakingToken);
    }

    /// @inheritdoc IStakingManager
    function getUserAccruedRewardsForToken(address user, address stakingToken, address rewardToken)
        external
        view
        returns (uint256)
    {
        return tokenInfo[stakingToken].accruedRewards[user][rewardToken];
    }

    /// @inheritdoc IStakingManager
    function getUserTotalRewardsForToken(address user, address stakingToken, address rewardToken)
        public
        view
        returns (uint256)
    {
        TokenInfo storage stakingTokenInfo = tokenInfo[stakingToken];
        RewardTokenData memory rewardTokenData = stakingTokenInfo.rewardTokenData[rewardToken];

        uint256 totalStaked = getTotalStaked(stakingToken);
        uint256 userStakedBalance = getUserStakedBalance(user, stakingToken);
        uint256 rewardPerStakedToken = rewardTokenData.rewardPerStakedToken;

        if (rewardTokenData.lastUpdatedTimestamp < block.timestamp && totalStaked > 0) {
            uint256 tokenRewards = _getTotalPendingRewards(stakingToken, rewardToken);
            rewardPerStakedToken += Math.mulDiv(tokenRewards, REWARD_PER_STAKED_TOKEN_BASE, totalStaked);
        }

        uint256 currentRewards = stakingTokenInfo.accruedRewards[user][rewardToken];
        uint256 pendingRewards = userStakedBalance * rewardPerStakedToken;

        return (currentRewards + pendingRewards - stakingTokenInfo.rewardDebt[user][rewardToken])
            / REWARD_PER_STAKED_TOKEN_BASE;
    }

    /// @inheritdoc IStakingManager
    function setIsPaused(bool paused) external onlyOwner {
        isPaused = paused;

        emit SetPaused(paused);
    }

    /// @inheritdoc IStakingManager
    function setStakedTokenImplementation(address implementation) external onlyOwner {
        stakedTokenImplementation = implementation;

        emit SetStakedTokenImplementation(implementation);
    }

    /// @inheritdoc IStakingManager
    function setLockingManager(address stakingToken, address lockingManager) external onlyOwner {
        tokenInfo[stakingToken].lockingManager = ILockingManager(lockingManager);

        emit SetLockingManager(stakingToken, address(lockingManager));
    }

    /// @inheritdoc IStakingManager
    function startStaking(address asset) external onlyOwner {
        if (isStakingStarted(asset)) {
            revert StakingAlreadyStarted();
        }

        if (getStakedToken(asset) == address(0)) {
            StakedTokenBeaconProxy stakedTokenBeaconProxy = new StakedTokenBeaconProxy(
                address(this),
                abi.encodeWithSelector(
                    StakedToken.initialize.selector,
                    address(this),
                    asset,
                    string.concat("Staked ", IERC20Metadata(asset).name()),
                    string.concat("st", IERC20Metadata(asset).symbol())
                )
            );

            tokenInfo[asset].stakedToken = address(stakedTokenBeaconProxy);
        }

        stakingTokens.push(asset);

        emit StartStaking(asset);
    }

    /// @inheritdoc IStakingManager
    function configureRewardToken(address stakingToken, address rewardToken, RewardTokenConfig calldata config)
        external
        onlyOwner
        onlyActiveStaking(stakingToken)
    {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        address[] storage rewardTokenList = _tokenInfo.rewardTokens;

        for (uint256 i = 0; i < rewardTokenList.length; i++) {
            if (rewardTokenList[i] == rewardToken) {
                _updateRewards(stakingToken, rewardToken);

                _tokenInfo.rewardTokenConfig[rewardToken] = config;
                return;
            }
        }

        rewardTokenList.push(rewardToken);
        _tokenInfo.rewardTokenConfig[rewardToken] = config;

        emit ConfigureRewardToken(
            stakingToken, rewardToken, config.startTimestamp, config.endTimestamp, config.emissionPerSecond
        );
    }

    /// @inheritdoc IStakingManager
    function stake(address stakingToken, uint256 amount, address recipient) external onlyActiveStaking(stakingToken) {
        SafeERC20.safeTransferFrom(IERC20(stakingToken), msg.sender, address(this), amount);
        IStakedToken(getStakedToken(stakingToken)).mint(recipient, amount);

        emit Stake(stakingToken, msg.sender, recipient, amount);
    }

    /// @inheritdoc IStakingManager
    function unstake(address stakingToken, uint256 amount, address recipient) public {
        IStakedToken(getStakedToken(stakingToken)).burn(msg.sender, amount);
        SafeERC20.safeTransfer(IERC20(stakingToken), recipient, amount);

        emit Unstake(stakingToken, msg.sender, recipient, amount);
    }

    /// @inheritdoc IStakingManager
    function unstakeAndClaim(address stakingToken, uint256 amount, address recipient) external {
        unstake(stakingToken, amount, recipient);
        claimRewards(stakingToken, recipient);
    }

    /// @inheritdoc IStakingManager
    function claimRewards(address stakingToken, address recipient) public {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];

        for (uint256 i = 0; i < _tokenInfo.rewardTokens.length; i++) {
            claimRewardsForToken(stakingToken, _tokenInfo.rewardTokens[i], recipient);
        }
    }

    /// @inheritdoc IStakingManager
    function claimRewardsForToken(address stakingToken, address rewardToken, address recipient) public {
        _updateRewards(stakingToken, rewardToken);

        uint256 userTotalRewards = getUserTotalRewardsForToken(msg.sender, stakingToken, rewardToken);

        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        RewardTokenData memory rewardTokenData = _tokenInfo.rewardTokenData[rewardToken];
        uint256 userStakedBalance = getUserStakedBalance(msg.sender, stakingToken);

        _tokenInfo.rewardDebt[msg.sender][rewardToken] = userStakedBalance * rewardTokenData.rewardPerStakedToken;
        _tokenInfo.accruedRewards[msg.sender][rewardToken] = 0;

        SafeERC20.safeTransfer(IERC20(rewardToken), recipient, userTotalRewards);

        emit ClaimRewardsForToken(msg.sender, recipient, stakingToken, rewardToken);
    }

    /// @inheritdoc IStakingManager
    function updateHook(address stakingToken, address sender, address recipient, uint256 value)
        external
        onlyStakedToken(stakingToken)
    {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        address[] memory rewardTokens = _tokenInfo.rewardTokens;

        uint256 senderCurrentBalance = getUserStakedBalance(sender, stakingToken);
        uint256 recipientCurrentBalance = getUserStakedBalance(recipient, stakingToken);

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address rewardToken = rewardTokens[i];

            _updateRewards(stakingToken, rewardToken);

            // If sender is zero addrees, it means that this is mint operation which means that user is depositing so we don't need to update rewards for sender
            if (sender != address(0)) {
                _updateUserRewards(
                    sender, stakingToken, rewardToken, senderCurrentBalance, senderCurrentBalance - value
                );
            }

            // If recipient is zero address, it means that this is burn operation which means that user is withdrawing so we don't need to update rewards for recipient
            if (recipient != address(0)) {
                _updateUserRewards(
                    recipient, stakingToken, rewardToken, recipientCurrentBalance, recipientCurrentBalance + value
                );
            }
        }
    }

    function _updateRewards(address stakingToken, address rewardToken) internal {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        RewardTokenData storage rewardTokenData = _tokenInfo.rewardTokenData[rewardToken];

        uint256 totalStaked = getTotalStaked(stakingToken);

        if (totalStaked == 0) {
            rewardTokenData.lastUpdatedTimestamp = block.timestamp;
            return;
        }

        uint256 tokenRewards = _getTotalPendingRewards(stakingToken, rewardToken);
        rewardTokenData.rewardPerStakedToken += Math.mulDiv(tokenRewards, REWARD_PER_STAKED_TOKEN_BASE, totalStaked);
        rewardTokenData.lastUpdatedTimestamp = block.timestamp;
    }

    function _updateUserRewards(
        address user,
        address stakingToken,
        address rewardToken,
        uint256 userCurrentBalance,
        uint256 userFutureBalance
    ) internal {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        RewardTokenData memory rewardTokenData = _tokenInfo.rewardTokenData[rewardToken];

        if (userCurrentBalance > 0) {
            // Calculate how much rewards user has accrued until now
            uint256 userAccruedRewards =
                userCurrentBalance * rewardTokenData.rewardPerStakedToken - _tokenInfo.rewardDebt[user][rewardToken];

            _tokenInfo.accruedRewards[user][rewardToken] += userAccruedRewards;
        }

        // Update reward debt of user
        _tokenInfo.rewardDebt[user][rewardToken] = userFutureBalance * rewardTokenData.rewardPerStakedToken;
    }

    function _getTotalPendingRewards(address stakingToken, address rewardToken) private view returns (uint256) {
        TokenInfo storage _tokenInfo = tokenInfo[stakingToken];
        RewardTokenData memory rewardTokenData = _tokenInfo.rewardTokenData[rewardToken];
        RewardTokenConfig memory rewardTokenConfig = _tokenInfo.rewardTokenConfig[rewardToken];

        uint256 fromTimestamp = Math.max(rewardTokenConfig.startTimestamp, rewardTokenData.lastUpdatedTimestamp);
        uint256 toTimestamp = Math.min(block.timestamp, rewardTokenConfig.endTimestamp);

        if (fromTimestamp > toTimestamp) {
            return 0;
        }

        uint256 timePassed = toTimestamp - fromTimestamp;
        uint256 emissionPerSecond = rewardTokenConfig.emissionPerSecond;

        return timePassed * emissionPerSecond;
    }
}
