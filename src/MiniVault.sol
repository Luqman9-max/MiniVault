// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract MiniVault {
    using PriceConverter for uint256;
    using PriceConverter for AggregatorV3Interface;

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

    mapping (address => depositInfo) public addressToDepositInfo;

    struct depositInfo {
        uint256 amount;
        uint256 targetAmount;
        uint256 timeStamp;
    }

    constructor (
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

    modifier onlyOwner () {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    modifier hasBalance () {
        if (addressToDepositInfo[msg.sender].amount == 0e18){
            revert NoBalance();
        }
        _;
    }

    function deposit (uint256 target) external payable {
        uint256 usdValueSent = msg.value.getValue(s_priceFeed);

        if (usdValueSent == 0e18){
            revert ZeroDeposit();
        } else if (usdValueSent < MIN_USD) {
            revert NotEnoughDeposited();
        }

        uint256 usdTargetSet = target.getValue(s_priceFeed);

        if (usdTargetSet == 0e18) {
            revert InvalidTarget();
        }

        addressToDepositInfo[msg.sender].amount += msg.value;
        addressToDepositInfo[msg.sender].targetAmount += usdTargetSet;
        addressToDepositInfo[msg.sender].timeStamp = block.timestamp;

        emit Funded (msg.sender, msg.value, target);
    }

    function withdraw () external hasBalance {
        depositInfo memory userInfo = addressToDepositInfo[msg.sender];

        if (block.timestamp < userInfo.timeStamp + i_minLockDuration) {
            revert StillLocked();
        }

        (,int256 price,,uint256 updatedAt,) = s_priceFeed.latestRoundData();
        uint256 currentPrice = uint256(price) * 1e10;
        uint256 totalPrice = (currentPrice * userInfo.amount) / 1e18;

        uint256 totalAmountUsd = userInfo.amount;
        bool earlyExit = false; 

        if (block.timestamp - updatedAt > i_stalePriceThreshold) {
            revert StalePrice();
        }

        if (totalPrice < userInfo.targetAmount) {
            uint256 penalty = (totalAmountUsd * i_penaltyPercentage) / 100;

            totalAmountUsd -= penalty;
            earlyExit = true;

            (bool ownerSuccess, ) = i_owner.call{value: penalty}("");
            if (!ownerSuccess) revert TransferFailed();
        }

        delete addressToDepositInfo[msg.sender];

        (bool success, ) = payable(msg.sender).call{value: totalAmountUsd}("");
        if (!success) revert TransferFailed();

        emit Withdrew (msg.sender, totalAmountUsd, earlyExit);
    }

    function getDepositInfo (address user) external view returns (depositInfo memory) {
        return addressToDepositInfo[user];
    }

    function withdrawFees () external onlyOwner {
        (bool success, ) = i_owner.call{value: address(this).balance}("");
        if (!success) revert TransferFailed();
    }

    function getCurrentPrice () external view returns (uint256) {
        return s_priceFeed.getPrice();
    }

    function getVersionConfig () external view returns (uint256) {
        return s_priceFeed.version();
    }

    function getAddressToAmountDeposit (address user) external view returns (uint256) {
        return addressToDepositInfo[user].amount;
    }
} 