// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
 
import './IERC20.sol';
 
/// @title MyToken — Token ERC-20 pedagogique
/// @notice Implementation complete realisee en TP1
contract MyToken is IERC20 {
    // Storage
    string public name;
    string public symbol;
    uint8 public immutable decimals;
    uint256 public totalSupply;
    address public owner;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
 
    // Erreurs custom (TODO 1)
    error Unauthorized();
    error InsufficientBalance(uint256 available, uint256 required);
    error InsufficientAllowance(uint256 available, uint256 required);
    error ZeroAddress();
    error ZeroAmount();
 
    // Events supplementaires
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
 
    // Modifier (TODO 2)
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }
 
    // Constructor (TODO 3)
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = msg.sender;
        _mint(msg.sender, _initialSupply);
    }
 
    // ---- Fonctions ERC-20 publiques ----
    function transfer(address to, uint256 amount) external returns (bool) {
        // TODO 4
        if (to == address(0)) revert ZeroAddress();
        _transfer(msg.sender, to, amount);
        return true;
    }
 
    function approve(address spender, uint256 amount) external returns (bool) {
        // TODO 5
        if (spender == address(0)) revert ZeroAddress();
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
 
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        // TODO 6
        if (to == address(0)) revert ZeroAddress();
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            if (allowed < amount) revert InsufficientAllowance(allowed, amount);
            unchecked {
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        _transfer(from, to, amount);
        return true;
    }
 
    // ---- Fonctions admin ----
    function mint(address to, uint256 amount) external onlyOwner {
        // TODO 7
        _mint(to, amount);
    }
 
    function burn(uint256 amount) external {
        // TODO 8
        _burn(msg.sender, amount);
    }
 
    function transferOwnership(address newOwner) external onlyOwner {
        // TODO 9
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
 
    // ---- Fonctions internes (FOURNIES - ne pas modifier) ----
    function _transfer(address from, address to, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        unchecked {
            balanceOf[from] = bal - amount;
            balanceOf[to] += amount;
        }
        emit Transfer(from, to, amount);
    }
 
    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }
 
    function _burn(address from, uint256 amount) internal {
        uint256 bal = balanceOf[from];
        if (bal < amount) revert InsufficientBalance(bal, amount);
        unchecked {
            balanceOf[from] = bal - amount;
            totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }

    
}
