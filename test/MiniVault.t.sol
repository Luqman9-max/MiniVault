// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MiniVault} from "../src/MiniVault.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";

contract MiniVaultTest is Test {
    MiniVault public vault;
    HelperConfig public helperConfig;

    address public user = makeAddr("user");
    uint256 public constant DEPOSIT_AMOUNT = 0.1 ether;

    function setUp() public {
        // Inisialisasi HelperConfig untuk mendapatkan alamat price feed yang sesuai network
        helperConfig = new HelperConfig();
        address priceFeed = helperConfig.activeConfigAddress();

        // Deploy MiniVault dengan price feed dari HelperConfig
        vault = new MiniVault(priceFeed);

        // Kasih user 10 ETH/Token untuk testing
        vm.deal(user, 10 ether);
    }

    // ============ DEPOSIT TESTS ============

    function test_DepositSuccess() public {
        // Target price: USD value of 0.2 tokens
        // Since we are using BTC/USD feed, 0.2 tokens is worth a lot.
        uint256 targetAmount = 0.2 ether; 

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(targetAmount);

        assertEq(vault.getBalance(user), DEPOSIT_AMOUNT);
        // targetPrice in contract is stored in USD (18 decimals)
        // It's calculated as targetAmount.getValue(s_priceFeed)
        assertTrue(vault.getTargetPrice(user) > 0);
    }

    function test_DepositZeroReverts() public {
        vm.prank(user);
        vm.expectRevert(MiniVault.ZeroDeposit.selector);
        vault.deposit{value: 0}(0.1 ether);
    }

    function test_DepositBelowMinUsdReverts() public {
        // We need to send an amount that results in < $5 USD.
        // If BTC is $60,000, $5 is 5/60,000 BTC = 0.00008333 BTC
        uint256 tinyAmount = 1 gwei; // very small amount
        
        vm.prank(user);
        vm.expectRevert(MiniVault.NotEnoughDeposited.selector);
        vault.deposit{value: tinyAmount}(0.1 ether);
    }

    // ============ WITHDRAW TESTS ============

    function test_WithdrawSuccess() public {
        // Target price set lower than current value to allow immediate withdraw
        // current value is DEPOSIT_AMOUNT (0.1)
        uint256 lowTargetAmount = 0.05 ether; 

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(lowTargetAmount);

        // Now withdraw should work because current value (0.1) >= target value (0.05)
        vm.prank(user);
        vault.withdraw();

        assertEq(vault.getBalance(user), 0);
    }

    function test_WithdrawFailsBelowTarget() public {
        // Target price set higher than current value to prevent withdraw
        uint256 highTargetAmount = 0.2 ether; 

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(highTargetAmount);

        // Withdraw should fail because current value (0.1) < target value (0.2)
        vm.prank(user);
        vm.expectRevert(MiniVault.PriceTooLow.selector);
        vault.withdraw();
    }

    function test_WithdrawNoBalanceReverts() public {
        vm.prank(user);
        vm.expectRevert(MiniVault.NoBalance.selector);
        vault.withdraw();
    }

    function test_WithdrawReturnsFunds() public {
        uint256 lowTargetAmount = 0.05 ether;

        vm.startPrank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(lowTargetAmount);

        uint256 balanceAfterDeposit = user.balance;

        vault.withdraw();
        vm.stopPrank();

        // Setelah withdraw, saldo harus bertambah kembali sebesar deposit
        assertEq(user.balance, balanceAfterDeposit + DEPOSIT_AMOUNT);
        // Pastikan vault sudah kosong
        assertEq(vault.getBalance(user), 0);
    }
}