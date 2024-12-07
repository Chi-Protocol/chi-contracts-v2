// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {StakingManager} from "src/tokenomics/StakingManager.sol";
import {StakedToken} from "src/tokenomics/StakedToken.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployStakingManager is Script {
    address public constant PROXY_ADMIN = 0x347451E2BC19CB63E6A370d5Ab8d09591B8704Ea;
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        address stakingManagerImplementation = address(new StakingManager());
        console.log("StakingManager implementation deployed to: ", stakingManagerImplementation);

        address stakingManagerProxy = address(
            new TransparentUpgradeableProxy(
                stakingManagerImplementation, PROXY_ADMIN, abi.encodeWithSelector(StakingManager.initialize.selector)
            )
        );
        console.log("StakingManager proxy deployed to: ", stakingManagerProxy);

        address stakedTokenImplementation = address(new StakedToken());
        console.log("StakedToken implementation deployed to: ", stakedTokenImplementation);

        StakingManager(stakingManagerProxy).setStakedTokenImplementation(stakedTokenImplementation);
        console.log("StakedToken implementation set to StakingManager");

        StakingManager(stakingManagerProxy).transferOwnership(INITIAL_OWNER);
        console.log("Ownership transferred to: ", INITIAL_OWNER);

        vm.stopBroadcast();
    }
}
