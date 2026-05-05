// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

library PriceConverter {
    function getPrice (AggregatorV3Interface s_priceFeed) internal view returns (uint256) {
        (, int256 answer, , , ) = s_priceFeed.latestRoundData();
        return uint256 (answer * 10000000000);
    }

    function getValue (uint256 amount, AggregatorV3Interface s_priceFeed) internal view returns (uint256) {
        uint256 pricePerToken = getPrice(s_priceFeed);
        uint256 totalAmount = (amount * pricePerToken) / 1e18;
        return totalAmount;
    }
}