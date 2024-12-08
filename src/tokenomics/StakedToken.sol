// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IStakingManager} from "../interfaces/IStakingManager.sol";

contract StakedToken is ERC20Upgradeable, OwnableUpgradeable {
    /// @dev Address of staking contract
    address staking;
    /// @dev Address of staking token
    address stakingToken;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _staking, address _stakingToken, string memory _name, string memory _symbol)
        external
        initializer
    {
        __ERC20_init(_name, _symbol);
        __Ownable_init();

        staking = _staking;
        stakingToken = _stakingToken;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function _beforeTokenTransfer(address sender, address recipient, uint256 amount) internal virtual override {
        IStakingManager(staking).updateHook(stakingToken, sender, recipient, amount);

        return super._beforeTokenTransfer(sender, recipient, amount);
    }

    receive() external payable {}
}
