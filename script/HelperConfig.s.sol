// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    configAddress public activeConfigAddress;

    uint8 public constant DECIMAL = 8;
    int256 public constant INITIAL_ANSWER = 2000e8;

    struct configAddress {
        address priceFeed;
    }

    constructor () {
        if (block.chainid == 11155111) {
            activeConfigAddress = sepoliaConfigAddress();
        } else if (block.chainid == 1) {
            activeConfigAddress = ethConfigAddress();
        } else {
            activeConfigAddress = mocksConfigAddress();
        }
    }

    function sepoliaConfigAddress () public pure returns (configAddress memory) {
        configAddress memory sepoliaAddress = configAddress({priceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306});
        return sepoliaAddress;
    }

    function ethConfigAddress () public pure returns (configAddress memory) {
        configAddress memory ethAddress = configAddress ({priceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419});
        return ethAddress;
    }

    function mocksConfigAddress () public returns (configAddress memory) {
        if (activeConfigAddress.priceFeed != address(0)){
            return activeConfigAddress;
        }

        vm.startBroadcast();
        MockV3Aggregator mockAdress = new MockV3Aggregator(DECIMAL, INITIAL_ANSWER);
        vm.stopBroadcast();

        configAddress memory mockConfig = configAddress({priceFeed: address(mockAdress)});
        return mockConfig;
    }

}
