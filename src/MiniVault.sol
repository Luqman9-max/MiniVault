// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract MiniVault {
    using PriceConverter for uint256;

    struct DepositInfo {
        uint256 amount;
        uint256 targetUsd;
        uint256 depositTimestamp;
    }

    uint256 public constant MIN_USD = 5e18;
    uint256 public immutable i_minLockDuration;
    uint256 public immutable i_penaltyPercentage;
    uint256 public immutable i_stalePriceThreshold;
    address public immutable i_owner;

    event Funded(address indexed user, uint256 amount, uint256 targetUsd);
    event Withdrew(address indexed user, uint256 amount, bool earlyExit);

    error ZeroDeposit();
    error InvalidTarget();
    error NoBalance();
    error StalePrice();
    error TransferFailed();
    error NotEnoughDeposited();
    error StillLocked();
    error NotOwner();

    AggregatorV3Interface public immutable s_priceFeed;

    mapping(address => DepositInfo) public s_deposits;

    modifier hasBalance() {
        if (s_deposits[msg.sender].amount == 0) {
            revert NoBalance();
        }
        _;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert NotOwner();
        _;
    }

    constructor(
        address priceFeed,
        uint256 minLockDuration,
        uint256 penaltyPercentage,
        uint256 stalePriceThreshold
    ) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_minLockDuration = minLockDuration;
        i_penaltyPercentage = penaltyPercentage;
        i_stalePriceThreshold = stalePriceThreshold;
        i_owner = msg.sender;
    }

    function deposit(uint256 _priceTarget) external payable {
        uint256 usdValueSent = msg.value.getValue(s_priceFeed);

        if (usdValueSent == 0e18) {
            revert ZeroDeposit();
        } else if (usdValueSent < MIN_USD) {
            revert NotEnoughDeposited();
        }

        uint256 targetPrice = _priceTarget.getValue(s_priceFeed);

        if (targetPrice == 0e18) {
            revert InvalidTarget();
        }

        s_deposits[msg.sender].amount += msg.value;
        s_deposits[msg.sender].targetUsd += targetPrice;
        s_deposits[msg.sender].depositTimestamp = block.timestamp;

        emit Funded(msg.sender, msg.value, targetPrice);
    }

    function withdraw() external hasBalance {
        DepositInfo memory userDeposit = s_deposits[msg.sender];

        // 1. Time-lock check
        if (block.timestamp < userDeposit.depositTimestamp + i_minLockDuration) {
            revert StillLocked();
        }

        // 2. Oracle Safety Check (Stale Price)
        (, int256 price,, uint256 updatedAt,) = s_priceFeed.latestRoundData();
        if (block.timestamp - updatedAt > i_stalePriceThreshold) {
            revert StalePrice();
        }

        uint256 currentEthPrice = uint256(price) * 1e10; // Adjust to 18 decimals
        uint256 currentUsdValue = (userDeposit.amount * currentEthPrice) / 1e18;

        uint256 amountToWithdraw = userDeposit.amount;
        bool earlyExit = false;

        // 3. Price Target & Penalty Logic
        if (currentUsdValue < userDeposit.targetUsd) {
            // Early exit with penalty
            uint256 penalty = (amountToWithdraw * i_penaltyPercentage) / 100;
            amountToWithdraw -= penalty;
            earlyExit = true;

            // Send penalty to owner
            (bool ownerSuccess,) = i_owner.call{value: penalty}("");
            if (!ownerSuccess) revert TransferFailed();
        }

        // Reset state
        delete s_deposits[msg.sender];

        (bool success,) = payable(msg.sender).call{value: amountToWithdraw}("");
        if (!success) revert TransferFailed();

        emit Withdrew(msg.sender, amountToWithdraw, earlyExit);
    }

    function getDepositInfo(address _user) external view returns (DepositInfo memory) {
        return s_deposits[_user];
    }

    // New function for owner to withdraw accumulated fees
    function withdrawFees() external onlyOwner {
        (bool success,) = i_owner.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }
}