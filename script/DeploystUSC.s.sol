// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DeployConstants} from "./library/DeployConstants.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {stUSC} from "src/tokenomics/stUSC.sol";
import {wstUSC} from "src/tokenomics/wstUSC.sol";

contract DeploystUSC is Script {
    address public constant PROXY_ADMIN = 0x347451E2BC19CB63E6A370d5Ab8d09591B8704Ea;
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        address stUSCImplementation = address(new stUSC());
        console.log("stUSC implementation deployed to: ", stUSCImplementation);

        address stUSCProxy = address(
            new TransparentUpgradeableProxy(
                stUSCImplementation, PROXY_ADMIN, abi.encodeWithSelector(stUSC.initialize.selector, DeployConstants.USC)
            )
        );
        console.log("stUSC proxy deployed to: ", stUSCProxy);

        stUSC(stUSCProxy).setStartTimestamp(block.timestamp);
        console.log("Start timestamp set to: ", block.timestamp);

        stUSC(stUSCProxy).transferOwnership(INITIAL_OWNER);
        console.log("Ownership transferred to: ", INITIAL_OWNER);

        address wstUSCImplementation = address(new wstUSC());
        console.log("wstUSC implementation deployed to: ", wstUSCImplementation);

        address wstUSCProxy = address(
            new TransparentUpgradeableProxy(
                wstUSCImplementation, PROXY_ADMIN, abi.encodeWithSelector(wstUSC.initialize.selector, stUSCProxy)
            )
        );
        console.log("wstUSC proxy deployed to: ", wstUSCProxy);

        wstUSC(wstUSCProxy).transferOwnership(INITIAL_OWNER);
        console.log("Ownership transferred to: ", INITIAL_OWNER);

        vm.stopBroadcast();
    }
}
