// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {DeployConstants} from "./library/DeployConstants.sol";
import {ArbitrageV5} from "src/ArbitrageV5.sol";
import {IArbitrageERC20} from "src/interfaces/IArbitrageERC20.sol";
import {IPriceFeedAggregator} from "src/interfaces/IPriceFeedAggregator.sol";
import {IReserveHolderV2} from "src/interfaces/IReserveHolderV2.sol";

contract DeployArbitrage is Script {
    address public constant INITIAL_OWNER = 0xE36fF60a9Ae677c2d742a3DeddCA46d0fA999327;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        console.log("Deployer address: ", deployerAddress);
        console.log("Deployer balance: ", deployerAddress.balance);
        console.log("BlockNumber: ", block.number);

        vm.startBroadcast(deployerPrivateKey);

        ArbitrageV5 arbitrage = new ArbitrageV5(
            IArbitrageERC20(DeployConstants.USC),
            IArbitrageERC20(DeployConstants.CHI),
            IPriceFeedAggregator(DeployConstants.PRICE_FEED_AGGREGATOR),
            IReserveHolderV2(DeployConstants.RESERVE_HOLDER_V1)
        );

        console.log("Arbitrage deployed to: ", address(arbitrage));

        arbitrage.updateArbitrager(0xB299D10b51CF6D3F64ceE90c2b0717f0f5103cf2, true);
        arbitrage.updateArbitrager(INITIAL_OWNER, true);

        console.log("Updated arbitrager and privileged");

        arbitrage.updatePrivileged(0xB299D10b51CF6D3F64ceE90c2b0717f0f5103cf2, true);
        arbitrage.updatePrivileged(INITIAL_OWNER, true);

        console.log("Updated arbitrager and privileged");

        arbitrage.updateArbitrager(0x28fD557FB94EB95e6bD888f60d6114b5d6759a49, true);
        console.log("Updated arbitrager");

        arbitrage.updateArbitrager(0x72f500Dd404593C6F1889fEEB03519f211ab4cF1, true);
        console.log("Updated arbitrager");

        arbitrage.transferOwnership(INITIAL_OWNER);
        console.log("Transfer ownership to: ", INITIAL_OWNER);

        vm.stopBroadcast();
    }
}
