// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {DevOpsTools} from "foundry-devops/src/DevOpsTools.sol";
import {MiniVault} from "../src/MiniVault.sol";
import {Script, console} from "forge-std/Script.sol";

/**
 * @notice Script untuk melakukan Deposit ke MiniVault
 */
contract DepositMiniVault is Script {
    uint256 constant SEND_VALUE = 0.1 ether; 

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MiniVault", block.chainid);
        depositMiniVault(mostRecentlyDeployed);
    }

    function depositMiniVault(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        MiniVault(payable(mostRecentlyDeployed)).deposit{value: SEND_VALUE}("");
        vm.stopBroadcast();
        console.log("Deposited MiniVault with %s", SEND_VALUE);
    }
}

/**
 * @notice Script untuk melakukan Penarikan (Withdraw) saldo oleh Pengguna
 */
contract WithdrawMiniVault is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MiniVault", block.chainid);
        withdrawMiniVault(mostRecentlyDeployed);
    }

    function withdrawMiniVault(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        MiniVault(mostRecentlyDeployed).withdraw();
        vm.stopBroadcast();
        console.log("User has withdrawn their balance from MiniVault!");
    }
}

/**
 * @notice Script untuk Owner menarik akumulasi biaya penalti
 */
contract WithdrawFeesMiniVault is Script {
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("MiniVault", block.chainid);
        withdrawFees(mostRecentlyDeployed);
    }

    function withdrawFees(address mostRecentlyDeployed) public {
        vm.startBroadcast();
        // Fungsi ini hanya bisa dipanggil oleh i_owner (deployer awal)
        MiniVault(mostRecentlyDeployed).withdrawFees();
        vm.stopBroadcast();
        console.log("Owner has withdrawn accumulated fees!");
    }
}
