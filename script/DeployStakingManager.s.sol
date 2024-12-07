// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {StakingManager} from "src/tokenomics/StakingManager.sol";

contract DeployStakingManager is Script {
    address public constant INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);
    }
}
