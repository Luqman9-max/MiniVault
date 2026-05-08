// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title VaultToken
 * @author Luqman Adiwidya
 * @notice Implementasi manual standar ERC20 untuk hadiah MiniVault.
 */
contract VaultToken {
    string public name = "MiniVault Token";
    string public symbol = "VAULT";
    uint8 public decimals = 18;

    uint256 private s_totalSupply;
    address public i_owner;

    mapping(address => uint256) private s_balances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    error OnlyOwner();

    constructor() {
        i_owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != i_owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Menambah saldo token untuk alamat tertentu.
     * @dev Hanya bisa dipanggil oleh owner (MiniVault Contract).
     */
    function mint(address to, uint256 amount) external onlyOwner {
        s_totalSupply += amount;
        s_balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    /**
     * @notice Mentransfer token antar wallet.
     */
    function transfer(address to, uint256 amount) external returns (bool) {
        if (s_balances[msg.sender] < amount) return false;
        
        s_balances[msg.sender] -= amount;
        s_balances[to] += amount;
        
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function balanceOf(address account) external view returns (uint256) {
        return s_balances[account];
    }

    function totalSupply() external view returns (uint256) {
        return s_totalSupply;
    }

    /// @notice Digunakan untuk memindahkan kepemilikan token ke kontrak MiniVault
    function transferOwnership(address newOwner) external onlyOwner {
        i_owner = newOwner;
    }
}
