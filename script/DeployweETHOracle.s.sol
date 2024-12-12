// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {DeployConstants} from "./library/DeployConstants.sol";
import {ChainlinkEthAdapter} from "src/oracles/ChainlinkEthAdapter.sol";
import {ExternalContractAddresses} from "src/library/ExternalContractAddresses.sol";

contract DeployweETHOracle is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        ChainlinkEthAdapter chainlinkEthAdapter =
            new ChainlinkEthAdapter(ExternalContractAddresses.weETH, ExternalContractAddresses.WEETH_ETH_CHAINLINK_FEED);

        console.log("ChainlinkEthAdapter deployed to: ", address(chainlinkEthAdapter));
        console.log("Name is: ", chainlinkEthAdapter.name());

        vm.stopBroadcast();
    }
}
