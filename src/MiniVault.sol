// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract MiniVault {
    using PriceConverter for uint256;

    // Custom errors (lebih hemat gas daripada require + string)
    error ZeroDeposit();
    error InvalidTarget();
    error NoBalance();
    error PriceTooLow();
    error TransferFailed();
    error NotEnoughDeposited();

    AggregatorV3Interface private s_priceFeed;

    uint256 public constant MIN_USD = 5e18;


    mapping (address => uint256) public balance;
    mapping (address => uint256) public targetPrice;

    event deposited (address indexed user, uint256 amount, uint256 _targetPrice);
    event withdrawn (address indexed user, uint256 totalAmount);

    constructor (address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function deposit (uint256 amountDeposited, uint256 _targetPrice) external payable {
        if (amountDeposited.getValue(s_priceFeed) == 0e18) {
            revert ZeroDeposit();
        } else if (amountDeposited.getValue(s_priceFeed) < MIN_USD) {
            revert NotEnoughDeposited();
        }

        if (_targetPrice.getTarget(s_priceFeed) <= 0e18) {
            revert InvalidTarget();
        }

        balance[msg.sender] += amountDeposited;
        targetPrice[msg.sender] = _targetPrice;
        
        emit deposited (msg.sender, amountDeposited, _targetPrice);
    }

    function withdraw () external {
        uint256 totalBalance = balance[msg.sender];
        uint256 priceNow = PriceConverter.getPrice(s_priceFeed);

        if (totalBalance == 0e18) revert NoBalance();
        if (priceNow < targetPrice[msg.sender]) revert PriceTooLow();

        balance[msg.sender] = 0;
        targetPrice[msg.sender] = 0;

        (bool success, ) = payable(msg.sender).call{value: totalBalance}("");
        if (!success) revert TransferFailed();

        emit withdrawn (msg.sender, totalBalance);
    }

    function getBalance () external view returns (uint256) {
        return balance[msg.sender];
    }
}