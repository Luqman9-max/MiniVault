// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {MiniVault} from "../src/MiniVault.sol";
import {VaultToken} from "../src/VaultToken.sol";

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
        // 1. Deploy Token Hadiah
        VaultToken vaultToken = new VaultToken();

        // 2. Deploy MiniVault dengan alamat token
        MiniVault miniVault = new MiniVault(
            priceFeed,
            minLockDuration,
            penaltyPercentage,
            stalePriceThreshold,
            address(vaultToken)
        );

        // 3. Alihkan kontrol minting ke MiniVault
        vaultToken.transferOwnership(address(miniVault));
        vm.stopBroadcast();

        return miniVault;
    }
}