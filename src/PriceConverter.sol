// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceConverter
 * @author Luqman Adiwidya
 * @notice Library untuk mengonversi nilai ETH ke USD menggunakan Chainlink Price Feeds.
 */
library PriceConverter {
    /**
     * @notice Mendapatkan harga ETH/USD terbaru.
     * @param s_priceFeed Antarmuka Oracle Chainlink.
     * @return Harga ETH dalam USD (18 desimal).
     */
    function getPrice (AggregatorV3Interface s_priceFeed) internal view returns (uint256) {
        (, int256 answer, , , ) = s_priceFeed.latestRoundData();
        return uint256 (answer * 10000000000);
    }

    /**
     * @notice Menghitung nilai USD dari sejumlah ETH.
     * @param amount Jumlah ETH dalam wei.
     * @param s_priceFeed Antarmuka Oracle Chainlink.
     * @return Nilai total dalam USD (18 desimal).
     */
    function getValue (uint256 amount, AggregatorV3Interface s_priceFeed) internal view returns (uint256) {
        uint256 pricePerToken = getPrice(s_priceFeed);
        uint256 totalAmount = (amount * pricePerToken) / 1e18;
        return totalAmount;
    }
}