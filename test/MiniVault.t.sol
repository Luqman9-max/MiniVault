// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MiniVault} from "../src/MiniVault.sol";
import {DeployMiniVault} from "../script/DeployMiniVault.s.sol";

contract MiniVaultTest is Test {
    MiniVault miniVault;

    address user = makeAddr("user");
    uint256 public AMOUNT_USD = 0.1 ether;

    function setUp () public {
        DeployMiniVault deployMiniVault = new DeployMiniVault();
        miniVault = deployMiniVault.run();

        vm.deal(user, 10 ether);
    }

    function test_DepositSuccess () public {
        uint256 targetPrice = 0.5 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        assertEq(miniVault.getBalance(user), AMOUNT_USD);
        assertTrue(miniVault.getTargetPrice(user) > 0);
    }

    function test_DepositZeroReverts() public {
        uint256 targetPrice = 0.1 ether;

        vm.expectRevert(MiniVault.ZeroDeposit.selector);
        vm.prank(user);
        miniVault.deposit{value: 0}(targetPrice);
    }

    function test_DepositBelowMinUsdReverts() public {
        uint256 targetPrice = 0.1 ether;
        uint256 amount = 1 gwei;

        vm.expectRevert(MiniVault.NotEnoughDeposited.selector);
        vm.prank(user);
        miniVault.deposit{value: amount}(targetPrice);
    } 

    function test_WithdrawSuccess() public {
        uint256 targetPrice = 0.05 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        vm.prank(user);
        miniVault.withdraw();

        assertEq(miniVault.getBalance(user), 0);
    }

    function test_WithdrawFailsBelowTarget() public {
        uint256 targetPrice = 5 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);
        
        vm.expectRevert(MiniVault.PriceTooLow.selector);
        vm.prank(user);
        miniVault.withdraw();
    }

    function test_WithdrawNoBalanceReverts() public {
        vm.expectRevert(MiniVault.NoBalance.selector);
        vm.prank(user);
        miniVault.withdraw();
    }

    function test_WithdrawReturnsFunds() public {
        uint256 targetPrice = 0.1 ether;

        vm.startPrank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        uint256 afterDepositBalance = user.balance;

        miniVault.withdraw();
        vm.stopPrank();

        assertEq(user.balance, afterDepositBalance + AMOUNT_USD);

        assertEq(miniVault.getBalance(user), 0);

    }
}