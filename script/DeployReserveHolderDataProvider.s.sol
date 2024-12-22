// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {ReserveHolderDataProvider} from "src/periphery/ReserveHolderDataProvider.sol";

contract DeployReserveHolderDataProvider is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        ReserveHolderDataProvider reserveHolderDataProvider = new ReserveHolderDataProvider();

        console.log("ReserveHolderDataProvider deployed to: ", address(reserveHolderDataProvider));

        vm.stopBroadcast();
    }
}
