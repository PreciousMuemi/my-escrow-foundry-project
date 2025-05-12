# Three-Party Escrow Smart Contract

A secure and decentralized escrow system implemented on the Ethereum blockchain using Foundry for development and testing.

## Overview

This smart contract implements a three-party escrow system where:
- A sender deposits funds
- A receiver confirms receipt of goods/services
- An arbitrator resolves potential disputes

## Features

- Secure fund management
- Multiple escrow states
- Dispute resolution system
- Event logging
- Access control

## Contract States

1. AwaitingPayment
2. AwaitingConfirmation
3. Dispute
4. Released
5. Refunded
6. Cancelled

## Getting Started

### Prerequisites

- [Foundry](https://github.com/foundry-rs/foundry)
- Solidity ^0.8.0

### Installation

```bash
git clone https://github.com/PreciousMuemi/my-escrow-foundry-project
cd my-escrow-foundry-project
forge install
```

### Testing

```bash
forge test
```

## Current Test Coverage

- Deployment validation
- Deposit functionality
- Fuzz testing for deposits

## License

MIT

## Author

Precious Muemi