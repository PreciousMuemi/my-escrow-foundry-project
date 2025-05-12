// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol"; // Import Foundry's test library
import "../src/ThreePartyEscrow.sol"; // Import your contract

contract EscrowTest is Test {
    ThreePartyEscrow escrow; // Declare an instance of your contract
    address payable sender;
    address payable receiver;
    address arbitrator;

    // This function runs before each test function
    function setUp() public {
        // Get test accounts provided by Foundry (like Hardhat's getSigners)
        // vm.addr(1) gives you a predictable address based on a number.
        sender = payable(vm.addr(1));
        receiver = payable(vm.addr(2));
        arbitrator = vm.addr(3);

        // Deploy the contract from the sender's address
        vm.startPrank(sender); // Start pretending to be the sender
        escrow = new ThreePartyEscrow(receiver, arbitrator);
        vm.stopPrank(); // Stop pretending
    }

    // --- Unit Test Example ---
    // Function names starting with 'test_' are unit tests
    function test_DeploymentSetsCorrectParties() public view {
        // Assertions using Foundry's built-in functions (like assertEq)
        assertEq(escrow.sender(), sender, "Sender should be deployer");
        assertEq(escrow.receiver(), receiver, "Receiver should be set");
        assertEq(escrow.arbitrator(), arbitrator, "Arbitrator should be set");
        assertEq(uint8(escrow.currentState()), uint8(ThreePartyEscrow.EscrowState.AwaitingPayment), "Initial state should be AwaitingPayment");
        assertEq(escrow.amount(), 0, "Initial amount should be 0");
    }

    // --- Unit Test Example: Happy Path Deposit ---
    function test_SenderDepositsFunds() public {
        uint256 depositAmount = 1 ether; // Example amount

        // Use vm.deal to give the sender some test Ether
        vm.deal(sender, depositAmount);

        // Start pranking as the sender to call the receive function with value
        vm.startPrank(sender);
        (bool success, ) = address(escrow).call{value: depositAmount}(""); // Call the receive function
        assertTrue(success, "Deposit call should succeed");
        vm.stopPrank();

        // Assert state changes
        assertEq(uint8(escrow.currentState()), uint8(ThreePartyEscrow.EscrowState.AwaitingConfirmation), "State should be AwaitingConfirmation after deposit");
        assertEq(escrow.amount(), depositAmount, "Amount should be updated");
        assertEq(address(escrow).balance, depositAmount, "Contract balance should match deposit");
    }

    // --- Fuzz Test Example ---
    // Function names starting with 'testFuzz_' are fuzz tests
    // Foundry will try random 'depositAmount' values
    function testFuzz_DepositAmountIsCorrect(uint256 depositAmount) public {
        // Skip test for zero deposit as require(msg.value > 0) will handle it
        if (depositAmount == 0) return;

        vm.deal(sender, depositAmount);
        vm.startPrank(sender);
        (bool success, ) = address(escrow).call{value: depositAmount}("");
        vm.stopPrank();

        // Assert that if the deposit was successful, the amount and balance are correct
        if (success) {
             assertEq(escrow.amount(), depositAmount, "Fuzzed: Amount should match deposit");
             assertEq(address(escrow).balance, depositAmount, "Fuzzed: Contract balance should match deposit");
        } else {
             // If it failed, it should be because the state wasn't AwaitingPayment (e.g., called twice)
                assertEq(uint8(escrow.currentState()), uint8(ThreePartyEscrow.EscrowState.AwaitingPayment), "Fuzzed: State should be AwaitingPayment if deposit failed");
            
        }
    }

    
}