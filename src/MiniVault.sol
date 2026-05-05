// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";

contract MiniVault {
    using PriceConverter for uint256;

    uint256 public constant MIN_USD = 5e18;

    event Funded(address indexed user, uint256 amount, uint256 targetUsd);
    event Withdrew(address indexed user, uint256 amount);

    error ZeroDeposit();
    error InvalidTarget();
    error NoBalance();
    error PriceTooLow();
    error TransferFailed();
    error NotEnoughDeposited();

    AggregatorV3Interface public immutable s_priceFeed;

    mapping (address => uint256) public balance;
    mapping (address => uint256) public _targetPrice;

    modifier hasBalance () {
        if (balance[msg.sender] == 0){
            revert NoBalance ();
        }
        _;
    }

    constructor (address priceFeed) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    function deposit (uint256 _priceTarget) external payable {
        uint256 usdValueSent = msg.value.getValue(s_priceFeed);

        if (usdValueSent == 0e18) {
            revert ZeroDeposit();
        } else if (usdValueSent < MIN_USD){
            revert NotEnoughDeposited ();
        }

        uint256 targetPrice = _priceTarget.getValue(s_priceFeed);

        if (targetPrice == 0e18) {
            revert InvalidTarget();
        }

        balance[msg.sender] += msg.value;
        _targetPrice[msg.sender] += targetPrice;

        emit Funded(msg.sender, msg.value, targetPrice);
    }

    function withdraw () external hasBalance {
        uint256 balanceWithdraw = balance[msg.sender];

        if (balanceWithdraw.getValue(s_priceFeed) < _targetPrice[msg.sender]){
            revert PriceTooLow();
        }

        balance[msg.sender] = 0;
        _targetPrice[msg.sender] = 0;
 

        (bool success, ) = payable(msg.sender).call{value: balanceWithdraw}("");
        if (!success) revert TransferFailed();

        emit Withdrew(msg.sender, balanceWithdraw);
    }

    function getBalance(address _user) external view returns (uint256) {
        return balance[_user];
    }

    function getTargetPrice(address _user) external view returns (uint256) {
        return _targetPrice[_user];
    }
}