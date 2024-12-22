// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ReserveHolderV2} from "src/reserve/ReserveHolderV2.sol";
import {PriceFeedAggregator} from "src/oracles/PriceFeedAggregator.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ReserveHolderDataProvider {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    struct ReserveData {
        address reserveAsset;
        uint256 reserveAssetPrice;
        uint256 reserveValue;
        uint256 rewardValue;
    }

    struct ReserveBreakdown {
        uint256 totalValue;
        ReserveData[] reserves;
    }

    function getReserveBreakdown(ReserveHolderV2 reserveHolder, PriceFeedAggregator priceFeedAggregator)
        external
        view
        returns (ReserveBreakdown memory breakdown)
    {
        address[] memory reserveAssets = reserveHolder.getReserveAssets();

        ReserveData[] memory reserves = new ReserveData[](reserveAssets.length + 1);

        for (uint256 i = 0; i < reserveAssets.length; i++) {
            address reserveAsset = reserveAssets[i];
            uint256 reserveAssetPrice = priceFeedAggregator.peek(reserveAsset);

            address adapter = address(reserveHolder.reserveAdapters(reserveAsset));
            uint256 reserveValue = IAdapter(adapter).getReserveValue();

            uint256 balance = IERC20(reserveAsset).balanceOf(adapter);
            uint256 balanceUsd = (balance * reserveAssetPrice) / 1e18;

            uint256 generatedYieldUsd = balanceUsd - reserveValue;

            reserves[i] = ReserveData({
                reserveAsset: reserveAsset,
                reserveAssetPrice: reserveAssetPrice,
                reserveValue: reserveValue,
                rewardValue: generatedYieldUsd
            });
        }

        uint256 wethValue = (IERC20(WETH).balanceOf(address(reserveHolder)) * priceFeedAggregator.peek(WETH)) / 1e18;
        reserves[reserves.length - 1] = ReserveData({
            reserveAsset: WETH,
            reserveAssetPrice: priceFeedAggregator.peek(WETH),
            reserveValue: wethValue,
            rewardValue: 0
        });

        uint256 totalValue = reserveHolder.getReserveValue();

        return ReserveBreakdown({totalValue: totalValue, reserves: reserves});
    }
}
