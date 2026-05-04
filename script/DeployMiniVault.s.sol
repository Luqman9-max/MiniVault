// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {Script} from "forge-std/Script.sol";
import {MiniVault} from "../src/MiniVault.sol";

contract DeployMiniVault is Script {
    function run () public returns (MiniVault) {
        MiniVault miniVault;
        HelperConfig helperConfig = new HelperConfig();
        address miniAddress = helperConfig.activeConfigAddress();

        vm.startBroadcast();
        miniVault = new MiniVault(miniAddress);
        vm.stopBroadcast();

        return miniVault;
    }
}