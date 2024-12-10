// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {LockingManager} from "src/tokenomics/LockingManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DeployConstants} from "./library/DeployConstants.sol";

contract DeployLockingManager is Script {
    address public constant PROXY_ADMIN = 0x347451E2BC19CB63E6A370d5Ab8d09591B8704Ea;
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    // TODO: Change this parameters every time you deploy a new contract
    address public constant LOCKING_TOKEN = 0x8f3871fD26Ac117f6E3D55E5f98E627Ca5d5e581;
    address public constant REWARD_TOKEN = DeployConstants.CHI;
    uint256 public constant EPOCH_START_TIME = 1733696402;
    uint256 public constant EPOCH_DURATION = 1 days;
    uint256 public constant INITIAL_REWARDS_PER_EPOCH = 10_000 * 1e18;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        address lockingManagerImplementation = address(new LockingManager());
        console.log("LockingManager implementation deployed to: ", lockingManagerImplementation);

        address lockingManagerProxy = address(
            new TransparentUpgradeableProxy(
                lockingManagerImplementation,
                PROXY_ADMIN,
                abi.encodeWithSelector(
                    LockingManager.initialize.selector,
                    LOCKING_TOKEN,
                    REWARD_TOKEN,
                    EPOCH_START_TIME,
                    EPOCH_DURATION,
                    INITIAL_REWARDS_PER_EPOCH
                )
            )
        );
        console.log("LockingManager proxy deployed to: ", lockingManagerProxy);

        LockingManager(lockingManagerProxy).transferOwnership(INITIAL_OWNER);
        console.log("Ownership transferred to: ", INITIAL_OWNER);

        vm.stopBroadcast();
    }
}
