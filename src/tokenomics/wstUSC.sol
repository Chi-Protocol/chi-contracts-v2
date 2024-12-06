// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract wstUSC is ERC4626Upgradeable, OwnableUpgradeable {
  function initialize(address stUSC) external initializer {
    __ERC4626_init_unchained(IERC20Upgradeable(stUSC));
    __ERC20_init_unchained("Wrapped Staked USC", "wstUSC");
    __Ownable_init_unchained();
  }

  function rescueTokens(IERC20 token, uint256 amount) external onlyOwner {
    token.transfer(msg.sender, amount);
  }
}
