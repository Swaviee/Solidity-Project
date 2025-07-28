// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IERC20
 * @dev Interface for ERC20 token standard
 */
interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

/**
 * @title LendingPlatform
 * @dev A decentralized lending platform that allows users to lend and borrow tokens
 * This contract implements basic lending functionality without collateral requirements
 */
contract LendingPlatform {
    // The ERC20 token used by this lending platform
    IERC20 public token;
    
    // Annual interest rate (percentage)
    uint256 public interestRate;
    
    // Mapping to track how much each user has lent to the platform
    mapping(address => uint256) public lendingBalance;
    
    // Mapping to track how much each user has borrowed from the platform
    mapping(address => uint256) public borrowingBalance;
    
    // Mapping to track when each user started borrowing (for interest calculation)
    mapping(address => uint256) public borrowStartTime;
    
    // Events to log important actions
    event TokensLent(address indexed lender, uint256 amount);
    event TokensBorrowed(address indexed borrower, uint256 amount);
    event TokensRepaid(address indexed borrower, uint256 amount, uint256 interest);
    
    /**
     * @dev Constructor to initialize the lending platform
     * @param _token Address of the ERC20 token to be used
     * @param _interestRate Annual interest rate as a percentage (e.g., 5 for 5%)
     */
    constructor(IERC20 _token, uint256 _interestRate) {
        require(address(_token) != address(0), "Token address cannot be zero");
        require(_interestRate > 0, "Interest rate must be greater than zero");
        
        token = _token;
        interestRate = _interestRate;
    }
    
    /**
     * @dev Allows users to lend tokens to the platform
     * Users must first approve this contract to spend their tokens
     * @param _amount Amount of tokens to lend
     */
    function lend(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        
        // Transfer tokens from user to this contract
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");
        
        // Update user's lending balance
        lendingBalance[msg.sender] += _amount;
        
        emit TokensLent(msg.sender, _amount);
    }
    
    /**
     * @dev Allows users to borrow tokens from the platform
     * @param _amount Amount of tokens to borrow
     */
    function borrow(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= _amount, "Insufficient liquidity in platform");
        require(borrowingBalance[msg.sender] == 0, "Must repay existing loan first");
        
        // Update user's borrowing balance and start time
        borrowingBalance[msg.sender] = _amount;
        borrowStartTime[msg.sender] = block.timestamp;
        
        // Transfer tokens from contract to user
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
        
        emit TokensBorrowed(msg.sender, _amount);
    }
    
    /**
     * @dev Allows users to repay their borrowed tokens with interest
     * Users must first approve this contract to spend the repayment amount
     */
    function repay() public {
        uint256 borrowedAmount = borrowingBalance[msg.sender];
        require(borrowedAmount > 0, "No outstanding loan to repay");
        
        // Calculate loan duration in seconds
        uint256 loanDuration = block.timestamp - borrowStartTime[msg.sender];
        
        // Calculate interest based on borrowed amount and duration
        uint256 interest = calculateInterest(borrowedAmount, loanDuration);
        
        // Total repayment amount = principal + interest
        uint256 totalRepayment = borrowedAmount + interest;
        
        // Transfer repayment from user to this contract
        require(token.transferFrom(msg.sender, address(this), totalRepayment), "Repayment transfer failed");
        
        // Reset user's borrowing data
        borrowingBalance[msg.sender] = 0;
        borrowStartTime[msg.sender] = 0;
        
        emit TokensRepaid(msg.sender, borrowedAmount, interest);
    }
    
    /**
     * @dev Internal function to calculate interest on borrowed amount
     * @param _amount Principal amount borrowed
     * @param _duration Duration of the loan in seconds
     * @return interest The calculated interest amount
     */
    function calculateInterest(uint256 _amount, uint256 _duration) internal view returns (uint256) {
        // Interest formula: principal * rate * time / (365 days * 100)
        // Rate is annual percentage, time is in seconds
        uint256 interest = (_amount * interestRate * _duration) / (365 days * 100);
        return interest;
    }
    
    /**
     * @dev View function to get current borrowing details for a user
     * @param _user Address of the user
     * @return borrowedAmount Amount currently borrowed
     * @return startTime When the borrowing started
     * @return currentInterest Current interest accrued
     */
    function getBorrowingDetails(address _user) public view returns (uint256 borrowedAmount, uint256 startTime, uint256 currentInterest) {
        borrowedAmount = borrowingBalance[_user];
        startTime = borrowStartTime[_user];
        
        if (borrowedAmount > 0 && startTime > 0) {
            uint256 currentDuration = block.timestamp - startTime;
            currentInterest = calculateInterest(borrowedAmount, currentDuration);
        } else {
            currentInterest = 0;
        }
    }
    
    /**
     * @dev View function to get the total amount needed for repayment
     * @param _user Address of the user
     * @return totalRepayment Total amount (principal + interest) needed for repayment
     */
    function getRepaymentAmount(address _user) public view returns (uint256 totalRepayment) {
        uint256 borrowedAmount = borrowingBalance[_user];
        
        if (borrowedAmount > 0 && borrowStartTime[_user] > 0) {
            uint256 currentDuration = block.timestamp - borrowStartTime[_user];
            uint256 interest = calculateInterest(borrowedAmount, currentDuration);
            totalRepayment = borrowedAmount + interest;
        } else {
            totalRepayment = 0;
        }
    }
    
    /**
     * @dev View function to get the platform's token balance (available liquidity)
     * @return balance Current token balance of the platform
     */
    function getPlatformBalance() public view returns (uint256 balance) {
        return token.balanceOf(address(this));
    }
}