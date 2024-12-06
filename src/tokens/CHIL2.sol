// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/ICHI.sol";
import "../interfaces/IToken.sol";
import "../interfaces/IOptimismMintableERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title CHI token contract for L2
contract CHIL2 is IOptimismMintableERC20, ERC20, ERC20Permit, Ownable {
  address public remoteToken;
  address public bridge;

  error NotBridge();

  event SetBridge(address indexed bridge);
  event Mint(address indexed account, uint256 amount);
  event Burn(address indexed account, uint256 amount);

  modifier onlyBridge() {
    if (msg.sender != bridge) {
      revert NotBridge();
    }

    _;
  }

  constructor(address _remoteToken, address _bridge) ERC20("CHI", "CHI") ERC20Permit("CHI") Ownable() {
    remoteToken = _remoteToken;
    bridge = _bridge;
  }

  function setBridge(address _bridge) external onlyOwner {
    bridge = _bridge;
    emit SetBridge(_bridge);
  }

  function mint(address account, uint256 amount) external onlyBridge {
    _mint(account, amount);
    emit Mint(account, amount);
  }

  function burn(address from, uint256 amount) public onlyBridge {
    _burn(from, amount);
    emit Burn(from, amount);
  }

  function supportsInterface(bytes4 _interfaceId) external pure virtual returns (bool) {
    bytes4 iface1 = type(IERC165).interfaceId;
    bytes4 iface3 = type(IOptimismMintableERC20).interfaceId;
    return _interfaceId == iface1 || _interfaceId == iface3;
  }
}
