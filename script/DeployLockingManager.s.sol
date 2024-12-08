// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {LockingManager} from "src/tokenomics/LockingManager.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract DeployLockingManager is Script {
    address public constant PROXY_ADMIN = 0x347451E2BC19CB63E6A370d5Ab8d09591B8704Ea;
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    // TODO: Change this parameters every time you deploy a new contract
    address public constant LOCKING_TOKEN = 0x044bCdf7deA1a825B7be24573b738462a4FE9D3f;
    address public constant REWARD_TOKEN = 0x3b21418081528845a6DF4e970bD2185545b712ba; // CHI
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
