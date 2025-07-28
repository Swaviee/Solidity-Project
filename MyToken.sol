// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title MyToken
 * @dev ERC20 token implementation for the decentralized lending platform
 * This contract creates a standard ERC20 token that will be used for lending and borrowing operations
 */
contract MyToken {
    // Token properties
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    
    // Mapping to track balances of each address
    mapping(address => uint256) public balanceOf;
    
    // Mapping to track allowances - owner => spender => amount
    mapping(address => mapping(address => uint256)) public allowance;
    
    // Events as defined in ERC20 standard
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @dev Constructor to initialize the token
     * @param _initialSupply The initial supply of tokens to mint
     */
    constructor(uint256 _initialSupply) {
        name = "MyToken";
        symbol = "MTK";
        decimals = 18;
        totalSupply = _initialSupply * 10**decimals;
        
        // Assign all initial tokens to the contract deployer
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    /**
     * @dev Transfer tokens from sender to recipient
     * @param _to Address of the recipient
     * @param _value Amount of tokens to transfer
     * @return success Boolean indicating if transfer was successful
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(_to != address(0), "Cannot transfer to zero address");
        require(balanceOf[msg.sender] >= _value, "Insufficient balance");
        
        balanceOf[msg.sender] -= _value;
        balanceOf[_to] += _value;
        
        emit Transfer(msg.sender, _to, _value);
        return true;
    }
    
    /**
     * @dev Approve spender to spend tokens on behalf of owner
     * @param _spender Address authorized to spend tokens
     * @param _value Amount of tokens to approve
     * @return success Boolean indicating if approval was successful
     */
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_spender != address(0), "Cannot approve zero address");
        
        allowance[msg.sender][_spender] = _value;
        
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    /**
     * @dev Transfer tokens from one address to another using allowance mechanism
     * @param _from Address to transfer tokens from
     * @param _to Address to transfer tokens to
     * @param _value Amount of tokens to transfer
     * @return success Boolean indicating if transfer was successful
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_from != address(0), "Cannot transfer from zero address");
        require(_to != address(0), "Cannot transfer to zero address");
        require(balanceOf[_from] >= _value, "Insufficient balance");
        require(allowance[_from][msg.sender] >= _value, "Insufficient allowance");
        
        balanceOf[_from] -= _value;
        balanceOf[_to] += _value;
        allowance[_from][msg.sender] -= _value;
        
        emit Transfer(_from, _to, _value);
        return true;
    }
}