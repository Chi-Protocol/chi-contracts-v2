// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "src/interfaces/ISTUSC.sol";

contract stUSC is ISTUSC, OwnableUpgradeable, ERC20PermitUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public constant REWARD_PER_SHARE_BASE = 1e18;

    bool public isPaused;
    IERC20 public usc;

    uint256 public totalStaked;
    uint256 public totalShares;
    uint256 public startTimestamp;
    uint256 public lastUpdatedTimestamp;
    uint256 public emissionPerSecond;
    uint256 public rewardPerShare;

    mapping(address => uint256) public accruedRewards;
    mapping(address => uint256) public rewardDebt;
    mapping(address => uint256) public shares;

    modifier whenNotPaused() {
        if (isPaused) {
            revert Paused();
        }

        _;
    }

    function initialize(IERC20 _usc) external initializer {
        __Ownable_init_unchained();
        __ERC20Permit_init_unchained("stUSC");
        __ERC20_init_unchained("Staked USC", "stUSC");

        usc = _usc;
    }

    /// @inheritdoc ISTUSC
    function setIsPaused(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }

    /// @inheritdoc ISTUSC
    function setUsc(IERC20 _usc) external onlyOwner {
        usc = _usc;
    }

    /// @inheritdoc ISTUSC
    function setEmissionPerSecond(uint256 _emissionPerSecond) external onlyOwner {
        _updateRewards();
        emissionPerSecond = _emissionPerSecond;
        emit SetEmissionPerSecond(_emissionPerSecond);
    }

    /// @inheritdoc ISTUSC
    function setStartTimestamp(uint256 _startTimestamp) external onlyOwner {
        startTimestamp = _startTimestamp;
        emit SetStartTimestamp(_startTimestamp);
    }

    function tokenToShares(uint256 amount, Math.Rounding rounding) public view returns (uint256) {
        return totalShares > 0 ? Math.mulDiv(amount, totalShares, totalSupply(), rounding) : amount;
    }

    /// @inheritdoc ISTUSC
    function stake(uint256 amount, address recipient) external {
        usc.safeTransferFrom(msg.sender, address(this), amount);
        _transfer(address(0), recipient, amount);
        emit Stake(msg.sender, recipient, amount);
    }

    /// @inheritdoc ISTUSC
    function unstake(uint256 amount, address recipient) external {
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientFunds();
        }

        _transfer(msg.sender, address(0), amount);
        usc.safeTransfer(recipient, amount);
        emit Unstake(msg.sender, recipient, amount);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return totalShares > 0 ? Math.mulDiv(shares[account], totalSupply(), totalShares) : 0;
    }

    function totalSupply() public view override returns (uint256) {
        return totalStaked + _getTotalPendingRewards();
    }

    function _transfer(address from, address to, uint256 amount) internal override whenNotPaused {
        uint256 senderCurrentShares = shares[from];
        uint256 recipientCurrentShares = shares[to];

        uint256 sendingShares = tokenToShares(amount, Math.Rounding.Up);
        uint256 receivingShares = tokenToShares(amount, Math.Rounding.Down);

        _updateRewards();

        // If sender is zero addrees, it means that this is mint operation which means that user is depositing so we don't need to update rewards for sender
        if (from != address(0)) {
            _updateUserRewards(from, senderCurrentShares, senderCurrentShares - sendingShares);
        }

        // If recipient is zero address, it means that this is burn operation which means that user is withdrawing so we don't need to update rewards for recipient
        if (to != address(0)) {
            _updateUserRewards(to, recipientCurrentShares, recipientCurrentShares + receivingShares);
        }

        if (to != address(0)) {
            totalShares += receivingShares;
            totalStaked += amount;
        }
        if (from != address(0)) {
            totalShares -= sendingShares;
            totalStaked -= amount;
        }
    }

    function _updateRewards() internal {
        if (totalSupply() == 0) {
            lastUpdatedTimestamp = block.timestamp;
            return;
        }

        uint256 tokenRewards = _getTotalPendingRewards();
        totalStaked += tokenRewards;

        if (totalShares > 0) rewardPerShare += Math.mulDiv(tokenRewards, REWARD_PER_SHARE_BASE, totalShares);
        lastUpdatedTimestamp = block.timestamp;
    }

    function _updateUserRewards(address user, uint256 userCurrentShares, uint256 userFutureShares) internal {
        if (userCurrentShares > 0) {
            // Calculate how much rewards user has accrued until now
            uint256 userAccruedRewards = userCurrentShares * rewardPerShare - rewardDebt[user];
            accruedRewards[user] += userAccruedRewards;
        }

        // Update reward debt of user
        rewardDebt[user] = userFutureShares * rewardPerShare;
        shares[user] = userFutureShares;
    }

    function _getTotalPendingRewards() private view returns (uint256) {
        if (totalStaked == 0) {
            return 0;
        }

        uint256 fromTimestamp = Math.max(startTimestamp, lastUpdatedTimestamp);
        uint256 toTimestamp = block.timestamp;

        if (fromTimestamp > toTimestamp) {
            return 0;
        }

        uint256 timePassed = toTimestamp - fromTimestamp;

        return timePassed * emissionPerSecond;
    }
}
