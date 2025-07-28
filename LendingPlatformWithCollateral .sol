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
 * @title LendingPlatformWithCollateral
 * @dev A decentralized lending platform that requires Ether collateral for borrowing tokens
 * This contract implements secure lending with collateral requirements to mitigate default risk
 */
contract LendingPlatformWithCollateral {
    // The ERC20 token used by this lending platform
    IERC20 public token;
    
    // Annual interest rate (percentage)
    uint256 public interestRate;
    
    // Collateral ratio required (percentage) - e.g., 150 means 150% collateralization
    uint256 public collateralRatio;
    
    // Mapping to track how much each user has lent to the platform
    mapping(address => uint256) public lendingBalance;
    
    // Mapping to track how much each user has borrowed from the platform
    mapping(address => uint256) public borrowingBalance;
    
    // Mapping to track when each user started borrowing (for interest calculation)
    mapping(address => uint256) public borrowStartTime;
    
    // Mapping to track Ether collateral deposited by each user
    mapping(address => uint256) public collateralBalance;
    
    // Events to log important actions
    event TokensLent(address indexed lender, uint256 amount);
    event TokensBorrowed(address indexed borrower, uint256 amount, uint256 collateralUsed);
    event TokensRepaid(address indexed borrower, uint256 amount, uint256 interest);
    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    
    /**
     * @dev Modifier to prevent reentrancy attacks
     */
    bool private locked;
    modifier noReentrancy() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }
    
    /**
     * @dev Constructor to initialize the lending platform with collateral
     * @param _token Address of the ERC20 token to be used
     * @param _interestRate Annual interest rate as a percentage (e.g., 5 for 5%)
     * @param _collateralRatio Required collateral ratio as a percentage (e.g., 150 for 150%)
     */
    constructor(IERC20 _token, uint256 _interestRate, uint256 _collateralRatio) {
        require(address(_token) != address(0), "Token address cannot be zero");
        require(_interestRate > 0, "Interest rate must be greater than zero");
        require(_collateralRatio >= 100, "Collateral ratio must be at least 100%");
        
        token = _token;
        interestRate = _interestRate;
        collateralRatio = _collateralRatio;
    }
    
    /**
     * @dev Allows users to deposit Ether as collateral
     * Users can deposit multiple times to increase their collateral balance
     */
    function depositCollateral() public payable noReentrancy {
        require(msg.value > 0, "Must deposit some Ether");
        
        collateralBalance[msg.sender] += msg.value;
        
        emit CollateralDeposited(msg.sender, msg.value);
    }
    
    /**
     * @dev Allows users to withdraw Ether collateral
     * Users can only withdraw if they have no outstanding loans or sufficient excess collateral
     * @param _amount Amount of Ether to withdraw
     */
    function withdrawCollateral(uint256 _amount) public noReentrancy {
        require(_amount > 0, "Amount must be greater than zero");
        require(collateralBalance[msg.sender] >= _amount, "Insufficient collateral balance");
        
        // Check if user has outstanding loans
        uint256 borrowedAmount = borrowingBalance[msg.sender];
        
        if (borrowedAmount > 0) {
            // Calculate required collateral for existing loan
            uint256 requiredCollateral = (borrowedAmount * collateralRatio) / 100;
            uint256 remainingCollateral = collateralBalance[msg.sender] - _amount;
            
            require(remainingCollateral >= requiredCollateral, "Cannot withdraw: would make loan undercollateralized");
        }
        
        // Update collateral balance and transfer Ether
        collateralBalance[msg.sender] -= _amount;
        
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        require(success, "Ether transfer failed");
        
        emit CollateralWithdrawn(msg.sender, _amount);
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
     * @dev Allows users to borrow tokens against their Ether collateral
     * @param _amount Amount of tokens to borrow
     */
    function borrow(uint256 _amount) public noReentrancy {
        require(_amount > 0, "Amount must be greater than zero");
        require(token.balanceOf(address(this)) >= _amount, "Insufficient liquidity in platform");
        require(borrowingBalance[msg.sender] == 0, "Must repay existing loan first");
        
        // Calculate required collateral for this loan
        uint256 requiredCollateral = (_amount * collateralRatio) / 100;
        require(collateralBalance[msg.sender] >= requiredCollateral, "Insufficient collateral");
        
        // Update user's borrowing balance and start time
        borrowingBalance[msg.sender] = _amount;
        borrowStartTime[msg.sender] = block.timestamp;
        
        // Transfer tokens from contract to user
        require(token.transfer(msg.sender, _amount), "Token transfer failed");
        
        emit TokensBorrowed(msg.sender, _amount, requiredCollateral);
    }
    
    /**
     * @dev Allows users to repay their borrowed tokens with interest
     * Users must first approve this contract to spend the repayment amount
     */
    function repay() public noReentrancy {
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
     * @dev View function to get maximum borrowable amount based on user's collateral
     * @param _user Address of the user
     * @return maxBorrow Maximum amount the user can borrow
     */
    function getMaxBorrowAmount(address _user) public view returns (uint256 maxBorrow) {
        uint256 userCollateral = collateralBalance[_user];
        
        // If user has existing loan, reduce available collateral
        uint256 borrowedAmount = borrowingBalance[_user];
        if (borrowedAmount > 0) {
            uint256 usedCollateral = (borrowedAmount * collateralRatio) / 100;
            if (userCollateral > usedCollateral) {
                userCollateral = userCollateral - usedCollateral;
            } else {
                return 0; // No additional borrowing capacity
            }
        }
        
        // Calculate max borrow based on available collateral
        maxBorrow = (userCollateral * 100) / collateralRatio;
    }
    
    /**
     * @dev View function to check if a loan is properly collateralized
     * @param _user Address of the user
     * @return isCollateralized True if loan is properly collateralized
     */
    function isLoanCollateralized(address _user) public view returns (bool isCollateralized) {
        uint256 borrowedAmount = borrowingBalance[_user];
        
        if (borrowedAmount == 0) {
            return true; // No loan means it's properly collateralized
        }
        
        uint256 requiredCollateral = (borrowedAmount * collateralRatio) / 100;
        return collateralBalance[_user] >= requiredCollateral;
    }
    
    /**
     * @dev View function to get current borrowing details for a user
     * @param _user Address of the user
     * @return borrowedAmount Amount currently borrowed
     * @return startTime When the borrowing started
     * @return currentInterest Current interest accrued
     * @return collateral User's collateral balance
     */
    function getBorrowingDetails(address _user) public view returns (uint256 borrowedAmount, uint256 startTime, uint256 currentInterest, uint256 collateral) {
        borrowedAmount = borrowingBalance[_user];
        startTime = borrowStartTime[_user];
        collateral = collateralBalance[_user];
        
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
    
    /**
     * @dev View function to get the platform's Ether balance (total collateral)
     * @return balance Current Ether balance of the platform
     */
    function getPlatformEtherBalance() public view returns (uint256 balance) {
        return address(this).balance;
    }
    
    /**
     * @dev Emergency function to allow contract owner to withdraw stuck tokens
     * This function should only be used in extreme circumstances (typically admin roles)
     */
    function emergencyWithdraw() public {
        // In a real implementation, this would have access control
        // For this project,anyone can call it for demonstration
        require(token.balanceOf(address(this)) > 0, "No tokens to withdraw");
        
        uint256 balance = token.balanceOf(address(this));
        require(token.transfer(msg.sender, balance), "Emergency withdraw failed");
    }
}