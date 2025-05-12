// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title ThreePartyEscrow
 * @dev This is the smart contract that holds the money while two parties figure things out.
 * It's like a digital middleman, but on the blockchain, so it's fair and transparent.
 * We've got a Sender (who pays), a Receiver (who gets paid), and an Arbitrator (the tie-breaker).
 */
contract ThreePartyEscrow {
    // States! These are the different phases our escrow can be in.
    enum EscrowState {
        AwaitingPayment, // Just chilling, waiting for the money to land.
        AwaitingConfirmation, // Money's here! Now the Receiver needs to say if they got the goods/service.
        Dispute, // Uh oh, beef! Sender and Receiver are arguing. Time for the Arbitrator.
        Released, // Success! Money went to the Receiver.
        Refunded, // Plan B: Money went back to the Sender.
        Cancelled // Aborted mission! Escrow stopped before money moved.

    }

    // Who's who in this whole setup? Storing their addresses here.
    address payable public sender; // The person sending the money. Gotta be payable to send funds out.
    address payable public receiver; // The person getting the money. Also payable.
    address public arbitrator; // The neutral judge. Doesn't handle the money directly, so no 'payable'.

    // How much money are we holding? Storing the amount here.
    uint256 public amount;

    // Keeping track of the current vibe/state of the escrow. Starts at 'AwaitingPayment'.
    EscrowState public currentState;

    // Modifier check: Is the person calling this function the Sender?
    modifier onlySender() {
        require(msg.sender == sender, "Nah, only the sender can do this.");
        _; // If the require passes, carry on with the function code.
    }

    // Modifier check: Is the person calling this function the Receiver?
    modifier onlyReceiver() {
        require(msg.sender == receiver, "Nope, only the receiver can do this.");
        _;
    }

    // Modifier check: Is the person calling this function the Arbitrator?
    modifier onlyArbitrator() {
        require(msg.sender == arbitrator, "Sorry, gotta be the arbitrator for this one.");
        _;
    }

    // Events! These are like broadcast messages on the blockchain. Super important for tracking stuff.
    event EscrowCreated(
        address indexed _sender, address indexed _receiver, address indexed _arbitrator, uint256 _amount
    );
    event FundsDeposited(uint256 _amount);
    event ReceiptConfirmed(address indexed _receiver);
    event DisputeRaised(address indexed _party); // Who started the drama?
    event FundsReleased(address indexed _receiver, uint256 _amount);
    event FundsRefunded(address indexed _sender, uint256 _amount);
    event EscrowCancelled();
    event ArbitrationDecision(address indexed _arbitrator, string _decision); // What did the judge decide?

    /**
     * @dev Constructor: This runs ONCE when the contract is deployed.
     * It sets up who the Receiver and Arbitrator are.
     * The person who deploys the contract automatically becomes the Sender.
     * @param _receiver The address of the person who's supposed to get the money later.
     * @param _arbitrator The address of the person who settles fights.
     */
    constructor(address payable _receiver, address _arbitrator) {
        // Basic checks to make sure the addresses aren't whack.
        require(_receiver != address(0), "Receiver address can't be zero. That's sus.");
        require(_arbitrator != address(0), "Arbitrator address can't be zero either. Gotta be a real person.");
        require(_receiver != msg.sender, "Sender and Receiver can't be the same person. That defeats the point.");
        require(_arbitrator != msg.sender, "Sender and Arbitrator can't be the same. No cheating!");
        require(_arbitrator != _receiver, "Receiver and Arbitrator can't be the same. Gotta be neutral!");

        sender = payable(msg.sender); // The person deploying = the sender. Simple.
        receiver = _receiver;
        arbitrator = _arbitrator;
        currentState = EscrowState.AwaitingPayment; // Starting state: waiting for the money.
        amount = 0; // Amount will be set when the sender sends the money.

        emit EscrowCreated(sender, receiver, arbitrator, amount); // Announce that the escrow is live!
    }

    /**
     * @dev This function is how the Sender sends the money to the contract.
     * It's a special function that triggers when someone sends Ether/LSK directly to the contract address.
     * Can only happen in the 'AwaitingPayment' state and only by the Sender.
     */
    receive() external payable {
        // Gotta be in the right state to receive funds.
        require(currentState == EscrowState.AwaitingPayment, "Can only drop funds when waiting for payment.");
        // And it has to be the actual sender sending it.
        require(msg.sender == sender, "Only the sender is allowed to deposit funds.");
        // And obviously, gotta send more than zero!
        require(msg.value > 0, "Gotta send some actual value, my dude.");

        amount = msg.value; // Store how much was sent.
        currentState = EscrowState.AwaitingConfirmation; // Okay, money's here, now we wait for confirmation.

        emit FundsDeposited(amount); // Let everyone know the funds landed!
    }

    /**
     * @dev Receiver calls this when they're happy with the goods/service.
     * Only the Receiver can call this, and only when we're waiting for confirmation.
     * If they confirm, the money goes to them!
     */
    function confirmReceipt() external onlyReceiver {
        require(currentState == EscrowState.AwaitingConfirmation, "Can only confirm when waiting for confirmation.");

        _releaseFunds(); // Send the money to the receiver!
        currentState = EscrowState.Released; // Update state to 'Released'.

        emit ReceiptConfirmed(receiver); // Announce that the receiver confirmed!
    }

    /**
     * @dev If things go sideways, either the Sender or Receiver can call this to raise a dispute.
     * This puts the Arbitrator in charge.
     * Can only be called when waiting for confirmation.
     */
    function raiseDispute() external {
        require(
            currentState == EscrowState.AwaitingConfirmation, "Can only raise a dispute when waiting for confirmation."
        );
        require(msg.sender == sender || msg.sender == receiver, "Only the sender or receiver can start a dispute.");

        currentState = EscrowState.Dispute; // Okay, things are heated. Moving to the 'Dispute' state.

        emit DisputeRaised(msg.sender); // Who started the drama?
    }

    /**
     * @dev The Arbitrator's moment! They call this to decide who gets the money.
     * Only the Arbitrator can call this, and only when we're in the 'Dispute' state.
     * @param releaseToReceiver True means Receiver gets the money, False means Sender gets it back.
     */
    function arbitrate(bool releaseToReceiver) external onlyArbitrator {
        require(currentState == EscrowState.Dispute, "Can only arbitrate when there's a dispute.");

        if (releaseToReceiver) {
            _releaseFunds(); // Arbitrator says Receiver wins!
            currentState = EscrowState.Released; // Update state.
            emit ArbitrationDecision(arbitrator, "Release to Receiver"); // Log the decision.
        } else {
            _refundFunds(); // Arbitrator says Sender gets money back!
            currentState = EscrowState.Refunded; // Update state.
            emit ArbitrationDecision(arbitrator, "Refund to Sender"); // Log the decision.
        }
    }

    /**
     * @dev Internal function to send the money to the Receiver.
     * This is the actual transfer logic. Called by confirmReceipt or arbitrate.
     */
    function _releaseFunds() internal {
        // Double check we actually have the money to send.
        require(address(this).balance >= amount, "Uh oh, contract balance is low. Something's wrong.");

        // Sending the money using the .call method. It's generally safer these days.
        (bool success,) = receiver.call{value: amount}("");
        require(success, "Sending funds to receiver failed. Big yikes.");

        emit FundsReleased(receiver, amount); // Announce the successful release!
    }

    /**
     * @dev Internal function to send the money back to the Sender.
     * This is the actual refund logic. Called by arbitrate.
     */
    function _refundFunds() internal {
        // Double check we actually have the money to send.
        require(address(this).balance >= amount, "Uh oh, contract balance is low. Something's wrong.");

        // Sending the money back to the sender using .call.
        (bool success,) = sender.call{value: amount}("");
        require(success, "Refunding funds to sender failed. That's not good.");

        emit FundsRefunded(sender, amount); // Announce the successful refund!
    }

    /**
     * @dev Sender can cancel the escrow, but ONLY if they haven't sent the money yet.
     * Can only be called by the Sender in the 'AwaitingPayment' state.
     */
    function cancelEscrow() external onlySender {
        require(currentState == EscrowState.AwaitingPayment, "Can only cancel before sending funds.");

        currentState = EscrowState.Cancelled; // Update state to 'Cancelled'.

        emit EscrowCancelled(); // Escrow is no more.
    }

    /**
     * @dev Wanna know the current status of the escrow? Call this.
     * @return The current state as an EscrowState enum value.
     */
    function getEscrowState() external view returns (EscrowState) {
        return currentState; // Just returning the current state. Easy peasy.
    }

    /**
     * @dev Who's involved in this escrow? Get the addresses here.
     * @return _sender The address of the sender.
     * @return _receiver The address of the receiver.
     * @return _arbitrator The address of the arbitrator.
     */
    function getParties() external view returns (address _sender, address _receiver, address _arbitrator) {
        return (sender, receiver, arbitrator); // Returning all the party addresses.
    }

    /**
     * @dev How much money is currently locked in this contract?
     * @return The amount in the contract's native currency (e.g., Ether or LSK).
     */
    function getAmount() external view returns (uint256) {
        return amount; // Returning the amount.
    }
}
