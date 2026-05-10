// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {PriceConverter} from "./PriceConverter.sol";
import {VaultToken} from "./VaultToken.sol";

/** 
 * @title MiniVault
 * @author Luqman Adiwidya
 * @notice Contract ini adalah brankas sederhana yang memungkinkan pengguna menyimpan ETH dengan target harga.
 * @dev Contract ini menggunakan Oracle Chainlink untuk verifikasi harga dan implementasi keamanan Oracle.
 */
contract MiniVault {
    using PriceConverter for uint256;
    using PriceConverter for AggregatorV3Interface;

    /// @notice Informasi deposit setiap pengguna
    struct depositInfo {
        uint256 amount;        // Jumlah ETH dalam wei
        uint256 targetAmount;  // Target harga dalam USD (18 desimal)
        uint256 timeStamp;     // Waktu deposit (Unix timestamp)
    }

    /// @notice Minimal deposit dalam USD (18 desimal)
    uint256 public constant MIN_USD = 5e18;
    
    /// @dev Waktu kunci dana minimal (detik)
    uint256 public immutable i_minLockDuration;
    
    /// @dev Besar penalti jika ditarik sebelum target (0-100)
    uint256 public immutable i_penaltyPercentage;
    
    /// @dev Toleransi waktu Oracle agar tidak dianggap basi (detik)
    uint256 public immutable i_stalePriceThreshold;
    
    /// @notice Alamat pemilik Contract
    address public immutable i_owner;

    /// @notice Token hadiah untuk pengguna
    VaultToken public immutable i_rewardToken;

    /// @notice Besarnya hadiah dasar per detik (0.001 VAULT)
    uint256 public constant REWARD_PER_SECOND = 1e15;

    event Funded(address indexed user, uint256 amount, uint256 targetUsd);
    event Withdrew(address indexed user, uint256 amount, bool earlyExit, uint256 rewardAmount);

    error ZeroDeposit();
    error InvalidTarget();
    error NoBalance();
    error StalePrice();
    error TransferFailed();
    error NotEnoughDeposited();
    error StillLocked();
    error NotOwner();

    /// @dev Antarmuka Oracle Chainlink
    AggregatorV3Interface public immutable s_priceFeed;

    /// @notice Data deposit yang dipetakan ke alamat pengguna
    mapping (address => depositInfo) public addressToDepositInfo;

    /// @notice Total biaya penalti yang terkumpul dan bisa ditarik oleh owner
    uint256 public s_accumulatedFees;

    /**
     * @param priceFeed Alamat Oracle ETH/USD
     * @param minLockDuration Durasi kunci minimal
     * @param penaltyPercentage Persentase penalti
     * @param stalePriceThreshold Threshold harga basi
     * @param rewardToken Alamat token hadiah
     */
    constructor (
        address priceFeed,
        uint256 minLockDuration,
        uint256 penaltyPercentage,
        uint256 stalePriceThreshold,
        address rewardToken
    ) {
        s_priceFeed = AggregatorV3Interface(priceFeed);
        i_minLockDuration = minLockDuration;
        i_penaltyPercentage = penaltyPercentage;
        i_stalePriceThreshold = stalePriceThreshold;
        i_rewardToken = VaultToken(rewardToken);
        i_owner = msg.sender;
    }

    /// @dev Modifier untuk membatasi akses hanya pemilik
    modifier onlyOwner () {
        if (msg.sender != i_owner) {
            revert NotOwner();
        }
        _;
    }

    /// @dev Modifier untuk memastikan pengguna memiliki saldo
    modifier hasBalance () {
        if (addressToDepositInfo[msg.sender].amount == 0){
            revert NoBalance();
        }
        _;
    }

    /**
     * @notice Pengguna menyimpan ETH dan menetapkan target harga USD
     * @param target Target harga ETH dalam USD (tanpa desimal, misal: 2500)
     * @dev Menyimpan jumlah asli ETH (wei) dan nilai USD dari target yang diinginkan
     */
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

        emit Funded (msg.sender, msg.value, usdTargetSet);
    }

    /**
     * @notice Menarik dana dari brankas
     * @dev Cek keamanan (Time-lock & Stale Price). Jika harga di bawah target, kena penalti.
     * Pengguna juga mendapatkan hadiah VaultToken.
     */
    function withdraw () external hasBalance {
        depositInfo memory userInfo = addressToDepositInfo[msg.sender];

        // 1. Cek Time-lock
        if (block.timestamp < userInfo.timeStamp + i_minLockDuration) {
            revert StillLocked();
        }

        // 2. Cek Oracle (Safety Check)
        (,int256 price,,uint256 updatedAt,) = s_priceFeed.latestRoundData();
        
        if (block.timestamp - updatedAt > i_stalePriceThreshold) {
            revert StalePrice();
        }

        uint256 currentPrice = uint256(price) * 1e10;
        uint256 totalPrice = (currentPrice * userInfo.amount) / 1e18;

        uint256 totalAmountToTransfer = userInfo.amount;
        bool earlyExit = false; 

        // 3. Hitung Hadiah Token (Yield)
        uint256 duration = block.timestamp - userInfo.timeStamp;
        uint256 rewardAmount = duration * REWARD_PER_SECOND;

        // 4. Cek Target & Penalti
        if (totalPrice < userInfo.targetAmount) {
            uint256 penalty = (totalAmountToTransfer * i_penaltyPercentage) / 100;

            totalAmountToTransfer -= penalty;
            s_accumulatedFees += penalty; 
            earlyExit = true;
        } else {
            // BONUS: Jika target tercapai, hadiah token dikali 2
            rewardAmount = rewardAmount * 2;
        }

        delete addressToDepositInfo[msg.sender];

        // Mint token hadiah ke pengguna
        if (rewardAmount > 0) {
            i_rewardToken.mint(msg.sender, rewardAmount);
        }

        (bool success, ) = payable(msg.sender).call{value: totalAmountToTransfer}("");
        if (!success) revert TransferFailed();

        emit Withdrew (msg.sender, totalAmountToTransfer, earlyExit, rewardAmount);
    }

    /// @notice Mendapatkan info deposit user
    function getDepositInfo (address user) external view returns (depositInfo memory) {
        return addressToDepositInfo[user];
    }

    /// @notice Owner menarik dana penalti yang terkumpul (hanya fee, bukan deposit user)
    function withdrawFees () external onlyOwner {
        uint256 fees = s_accumulatedFees;
        s_accumulatedFees = 0; 

        (bool success, ) = payable(i_owner).call{value: fees}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Mendapatkan harga ETH/USD saat ini
    function getCurrentPrice () external view returns (uint256) {
        return s_priceFeed.getPrice();
    }

    /// @notice Mendapatkan versi Oracle
    function getVersionConfig () external view returns (uint256) {
        return s_priceFeed.version();
    }

    /// @notice Mendapatkan saldo deposit pengguna
    function getAddressToAmountDeposit (address user) external view returns (uint256) {
        return addressToDepositInfo[user].amount;
    }

    /**
    * @dev Jika user kirim ETH langsung, otomatis arahkan ke fungsi deposit
    */
    receive() external payable {
        deposit(""); // Memanggil fungsi deposit dengan pesan kosong
    }
    
    /**
    * @dev Jika user memanggil fungsi yang salah, tetap arahkan ke deposit
    */
    fallback() external payable {
        deposit("");
    }
}