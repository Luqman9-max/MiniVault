// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMAL = 8;
    int256 public constant INITIAL_ANSWER = 2000e8;

    struct NetworkConfig {
        address priceFeed;
        uint256 minLockDuration;
        uint256 penaltyPercentage;
        uint256 stalePriceThreshold;
    }

    constructor () {
        if (block.chainid == 11155111) {
            activeNetworkConfig = sepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = ethConfig();
        } else {
            activeNetworkConfig = mocksConfig();
        }
    }

    function sepoliaConfig () public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306,
            minLockDuration: 1 days,
            penaltyPercentage: 10,
            stalePriceThreshold: 3600
        });
    }

    function ethConfig () public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419,
            minLockDuration: 1 days,
            penaltyPercentage: 10,
            stalePriceThreshold: 3600
        });
    }

    function mocksConfig () public returns (NetworkConfig memory) {
        if (activeNetworkConfig.priceFeed != address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator mockAddress = new MockV3Aggregator(DECIMAL, INITIAL_ANSWER);
        vm.stopBroadcast();

        return NetworkConfig({
            priceFeed: address(mockAddress),
            minLockDuration: 1 days,
            penaltyPercentage: 10,
            stalePriceThreshold: 3600
        });
    }

}
