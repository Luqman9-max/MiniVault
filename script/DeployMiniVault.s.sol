// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {MiniVault} from "../src/MiniVault.sol";

contract DeployMiniVault is Script {
    function run () public returns (MiniVault) {
        HelperConfig helperConfig = new HelperConfig();

        (
            address priceFeed,
            uint256 minLockDuration,
            uint256 penaltyPercentage,
            uint256 stalePriceThreshold
        ) = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        MiniVault miniVault = new MiniVault(
            priceFeed,
            minLockDuration,
            penaltyPercentage,
            stalePriceThreshold
        );
        vm.stopBroadcast();

        return miniVault;
    }
}