// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {DeployConstants} from "./library/DeployConstants.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ExternalContractAddresses} from "src/library/ExternalContractAddresses.sol";

import {ReserveHolderV2} from "src/reserve/ReserveHolderV2.sol";
import {StEthAdapter} from "src/reserve/StEthAdapter.sol";
import {WeEthAdapter} from "src/reserve/WeEthAdapter.sol";

contract DeployReserveHolderWithAdapters is Script {
    address public constant PROXY_ADMIN = 0x347451E2BC19CB63E6A370d5Ab8d09591B8704Ea;
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        address reserveHolderImplementation = address(new ReserveHolderV2());
        console.log("ReserveHolderV2 implementation deployed to: ", reserveHolderImplementation);

        address reserveHolderProxy = address(
            new TransparentUpgradeableProxy(
                reserveHolderImplementation,
                PROXY_ADMIN,
                abi.encodeWithSelector(ReserveHolderV2.initialize.selector, DeployConstants.PRICE_FEED_AGGREGATOR)
            )
        );
        console.log("ReserveHolderV2 proxy deployed to: ", reserveHolderProxy);

        StEthAdapter stEthAdapter =
            new StEthAdapter(reserveHolderProxy, DeployConstants.PRICE_FEED_AGGREGATOR, ExternalContractAddresses.stETH);
        console.log("StEthAdapter deployed to: ", address(stEthAdapter));

        WeEthAdapter weEthAdapter =
            new WeEthAdapter(reserveHolderProxy, DeployConstants.PRICE_FEED_AGGREGATOR, ExternalContractAddresses.weETH);
        console.log("WeEthAdapter deployed to: ", address(weEthAdapter));

        ReserveHolderV2(reserveHolderProxy).addReserveAsset(
            ExternalContractAddresses.stETH, address(stEthAdapter), 10_00
        );
        console.log("StEthAdapter added to ReserveHolderV2");

        ReserveHolderV2(reserveHolderProxy).addReserveAsset(
            ExternalContractAddresses.weETH, address(weEthAdapter), 10_00
        );
        console.log("WeEthAdapter added to ReserveHolderV2");

        ReserveHolderV2(reserveHolderProxy).setRebalancer(deployerAddress, true);
        ReserveHolderV2(reserveHolderProxy).setRebalancer(INITIAL_OWNER, true);
        console.log("Rebalancers set");

        ReserveHolderV2(reserveHolderProxy).setClaimer(INITIAL_OWNER);
        console.log("Claimer set");

        vm.stopBroadcast();
    }
}
