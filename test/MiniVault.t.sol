// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {MiniVault} from "../src/MiniVault.sol";
import {DeployMiniVault} from "../script/DeployMiniVault.s.sol";
import {MockV3Aggregator} from "./mocks/MockV3Aggregator.sol";

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

        assertEq(miniVault.getDepositInfo(user).amount, AMOUNT_USD);
        assertTrue(miniVault.getDepositInfo(user).targetAmount > 0);
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

    function test_withdrawSuccess () public {
        uint256 targetPrice = 0.01 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        vm.warp(block.timestamp + 1 days);

        MockV3Aggregator(address(miniVault.s_priceFeed())).updateAnswer(2000e8);

        vm.prank(user);
        miniVault.withdraw();

        assertEq(miniVault.getDepositInfo(user).amount, 0);

        uint256 expectedReward = (1 days * miniVault.REWARD_PER_SECOND()) * 2;

        assertEq(miniVault.i_rewardToken().balanceOf(user), expectedReward);
    }

    function test_withdrawPenalties () public {
        uint256 targetPrice = 10 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        vm.warp(block.timestamp + 1 days + 1);

        MockV3Aggregator(address(miniVault.s_priceFeed())).updateAnswer(2000e8);

        uint256 beforeWithdraw = user.balance;

        vm.prank(user);
        miniVault.withdraw();

        uint256 expectedWithdraw = (AMOUNT_USD * 90) / 100;

        assertEq(user.balance, beforeWithdraw + expectedWithdraw);
    }

    function test_WithdrawNoBalanceReverts() public {
        vm.expectRevert(MiniVault.NoBalance.selector);
        vm.prank(user);
        miniVault.withdraw();
    }

    function test_WithdrawLockedReverts() public {
        uint256 targetPrice = 0.1 ether;

        vm.prank(user);
        miniVault.deposit{value: AMOUNT_USD}(targetPrice);

        // No warp, should revert
        vm.expectRevert(MiniVault.StillLocked.selector);
        vm.prank(user);
        miniVault.withdraw();
    }
}