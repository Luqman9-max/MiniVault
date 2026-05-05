// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MiniVault} from "../src/MiniVault.sol";

contract MiniVaultTest is Test {
    MiniVault public vault;

    // Chainlink BTC/USD price feed di Celo Mainnet
    address constant BTC_USD_FEED = 0x128fE88eaa22bFFb868Bb3A584A54C96eE24014b;

    address public user = makeAddr("user");
    uint256 public constant DEPOSIT_AMOUNT = 1 ether;

    function setUp() public {
        // Fork Celo Mainnet
        vm.createSelectFork("celo_mainnet");

        // Deploy MiniVault dengan price feed ASLI dari Chainlink
        vault = new MiniVault(BTC_USD_FEED);

        // Kasih user 10 CELO untuk testing
        vm.deal(user, 10 ether);
    }

    // ============ PRICE TESTS ============

    function test_GetLatestPrice() public view {
        int256 price = vault.getLatestPrice();
        console.log("Harga BTC/USD saat ini (8 decimals):");
        console.logInt(price);
        // Harga harus > 0 (feed aktif)
        assertGt(price, 0, "Price should be greater than 0");
    }

    // ============ DEPOSIT TESTS ============

    function test_DepositSuccess() public {
        int256 targetPrice = 10000000000000; // $100,000 (8 decimals)

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(targetPrice);

        assertEq(vault.balances(user), DEPOSIT_AMOUNT);
        assertEq(vault.targetPrices(user), targetPrice);
    }

    function test_DepositZeroReverts() public {
        vm.prank(user);
        vm.expectRevert(MiniVault.ZeroDeposit.selector);
        vault.deposit{value: 0}(100000000);
    }

    // ============ WITHDRAW TESTS ============

    function test_WithdrawSuccess() public {
        // Target harga $1 — pasti di bawah harga BTC saat ini
        int256 lowTarget = 100000000; // $1 (8 decimals)

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(lowTarget);

        // Harga BTC pasti > $1, jadi withdraw harus berhasil
        vm.prank(user);
        vault.withdraw();

        assertEq(vault.balances(user), 0);
    }

    function test_WithdrawFailsBelowTarget() public {
        // Target harga $99,999,999 — pasti belum tercapai
        int256 highTarget = 9999999900000000; // $99,999,999 (8 decimals)

        vm.prank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(highTarget);

        // Harga BTC pasti < $99,999,999, jadi withdraw harus gagal
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
        int256 lowTarget = 100000000; // $1

        vm.startPrank(user);
        vault.deposit{value: DEPOSIT_AMOUNT}(lowTarget);

        uint256 balanceAfterDeposit = user.balance;

        vault.withdraw();
        vm.stopPrank();

        // Setelah withdraw, saldo harus bertambah kembali sebesar deposit
        assertGe(user.balance, balanceAfterDeposit);
        // Pastikan vault sudah kosong
        assertEq(vault.balances(user), 0);
    }
}