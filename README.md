# swift-algorand

![Swift 6.0+](https://img.shields.io/badge/Swift-6.0+-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20visionOS%20%7C%20Linux-lightgrey.svg)
![License](https://img.shields.io/badge/license-MIT-blue.svg)

> **Pre-1.0 Notice**: This SDK is under active development. The API may change between minor versions until 1.0. Not yet audited by a third-party security firm.

A modern Swift SDK for the Algorand blockchain. Built with Swift 6 and async/await.

## Features

- **Swift 6** - Built with the latest Swift concurrency features
- **Type-Safe** - Leveraging Swift's type system for safe blockchain interactions
- **Modern Async/Await** - No callbacks, just clean async code
- **Multi-Platform** - iOS 15+, macOS 11+, tvOS 15+, watchOS 8+, visionOS 1+, Linux
- **Pure Swift** - No SwiftUI dependencies, just core blockchain functionality

## Installation

### Swift Package Manager

Add Algorand to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", from: "0.1.0")
]
```

Or add it via Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/CorvidLabs/swift-algorand.git`

## Documentation

- **[Getting Started](documentation/GETTING_STARTED.md)** - Step-by-step guide for your first transaction
- **[Quick Start](documentation/QUICKSTART.md)** - Test the SDK in 5 minutes
- **[Testing Guide](documentation/TESTING.md)** - Comprehensive testing instructions
- **[Security](documentation/SECURITY.md)** - Best practices for production use
- **[Contributing](CONTRIBUTING.md)** - How to contribute to the project

## Quick Start

### Creating an Account

```swift
import Algorand

// Create a new random account
let account = Account()
print("Address: \(account.address)")
print("Mnemonic: \(account.mnemonic)")

// Import an existing account from mnemonic
let existingAccount = try Account(mnemonic: "your 25 word mnemonic here...")
```

### Connecting to the Network

```swift
// Connect to testnet
let algod = try AlgodClient(
    baseURL: "https://testnet-api.algonode.cloud"
)

// Get network status
let status = try await algod.status()
print("Current round: \(status.lastRound)")

// Get account information
let accountInfo = try await algod.accountInformation(account.address)
print("Balance: \(MicroAlgos(accountInfo.amount).algos) ALGO")
```

### Sending a Payment Transaction

```swift
// Get suggested transaction parameters
let params = try await algod.transactionParams()

// Build a payment transaction
let receiver = try Address(string: "RECEIVER_ADDRESS_HERE")
let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(MicroAlgos(algos: 1.0))  // 1 ALGO
    .params(params)
    .note("Hello, Algorand!")
    .build()

// Sign the transaction
let signedTxn = try SignedTransaction.sign(transaction, with: account)

// Submit to the network
let txID = try await algod.sendTransaction(signedTxn)
print("Transaction ID: \(txID)")

// Wait for confirmation
let confirmedTxn = try await algod.waitForConfirmation(transactionID: txID)
print("Confirmed in round: \(confirmedTxn.confirmedRound!)")
```

### Querying Blockchain Data

```swift
// Connect to indexer
let indexer = try IndexerClient(
    baseURL: "https://testnet-idx.algonode.cloud"
)

// Search for transactions
let txns = try await indexer.searchTransactions(
    address: account.address,
    limit: 10
)

for txn in txns.transactions {
    print("Transaction \(txn.id) in round \(txn.confirmedRound ?? 0)")
}

// Search for assets
let assets = try await indexer.searchAssets(
    name: "USDC",
    limit: 5
)

for asset in assets.assets {
    print("Asset \(asset.index): \(asset.params.name ?? "Unknown")")
}
```

## Core Concepts

### Addresses

Algorand addresses are represented by the `Address` type:

```swift
// From string
let address = try Address(string: "YOUR_ADDRESS_HERE")

// From bytes
let address = try Address(bytes: publicKeyBytes)
```

### Amounts

Amounts are type-safe with `MicroAlgos`:

```swift
// From microAlgos (1 ALGO = 1,000,000 microAlgos)
let amount = MicroAlgos(1_000_000)

// From Algos
let amount = MicroAlgos(algos: 1.0)

// Arithmetic operations
let total = MicroAlgos(algos: 1.0) + MicroAlgos(algos: 2.0)
let doubled = amount * 2
```

### Transactions

Build transactions using the builder pattern:

```swift
let transaction = try PaymentTransactionBuilder()
    .sender(sender)
    .receiver(receiver)
    .amount(MicroAlgos(algos: 1.0))
    .params(params)
    .note("Optional note")
    .validRounds(1000)  // Transaction valid for 1000 rounds
    .build()
```

### Signing

Sign transactions with an account:

```swift
let signedTxn = try SignedTransaction.sign(transaction, with: account)
```

## Architecture

The SDK is organized into several key components:

- **Core Types**: `Address`, `MicroAlgos`, `Account`
- **Transactions**: `PaymentTransaction`, `SignedTransaction`
- **Clients**: `AlgodClient` (node interaction), `IndexerClient` (queries)
- **Mnemonics**: BIP-39 mnemonic generation and validation

All clients use Swift's modern `async/await` concurrency model and are implemented as `actor` types for thread safety.

## Network Providers

The SDK works with any Algorand node or indexer. Here are some public endpoints:

### TestNet
- Algod: `https://testnet-api.algonode.cloud`
- Indexer: `https://testnet-idx.algonode.cloud`

### MainNet
- Algod: `https://mainnet-api.algonode.cloud`
- Indexer: `https://mainnet-idx.algonode.cloud`

### Custom Nodes
```swift
let algod = try AlgodClient(
    baseURL: "https://your-node.example.com",
    apiToken: "your-api-token"
)
```

## Testing

The SDK supports testing against three networks:

### LocalNet (Recommended for Development)

```bash
# Start local Algorand network with Docker
docker-compose up -d

# Run integration tests
ALGORAND_NETWORK=localnet swift test

# Manual testing
ALGORAND_NETWORK=localnet swift run algorand-example
```

### TestNet (Public Test Network)

```bash
# Create account and get test funds
ALGORAND_NETWORK=testnet swift run algorand-example
# Fund at: https://bank.testnet.algorand.network/

# Test with your account
export ALGORAND_MNEMONIC="your 25 word mnemonic"
ALGORAND_NETWORK=testnet SEND_TRANSACTION=1 swift run algorand-example
```

### MainNet (Production)

```bash
# Read-only queries (safe)
ALGORAND_NETWORK=mainnet swift run algorand-example
```

See [Testing Guide](documentation/TESTING.md) for detailed testing instructions.

## Requirements

- Swift 6.0+
- iOS 15.0+ / macOS 11.0+ / tvOS 15.0+ / watchOS 8.0+ / visionOS 1.0+
- Linux (with Swift 6.0+)
- Docker (optional, for localnet testing)

## License

MIT License - See LICENSE file for details

## Examples

The repository includes runnable examples in [Sources/AlgorandExample](Sources/AlgorandExample):

- **SendTransaction.swift** - Payment transaction example
- **AllTransactionTypes.swift** - Demonstrations of all transaction types
- **AssetExamples.swift** - Asset creation and management

Run the examples:
```bash
# Run with TestNet
ALGORAND_NETWORK=testnet swift run algorand-example

# Run with LocalNet
docker-compose up -d
ALGORAND_NETWORK=localnet swift run algorand-example
```

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Resources

- [Algorand Developer Portal](https://developer.algorand.org)
- [Algorand REST API](https://developer.algorand.org/docs/rest-apis/algod/)
- [Indexer API](https://developer.algorand.org/docs/rest-apis/indexer/)

## Credits

Built with inspiration from the Swift Algorand SDK ecosystem and modern Swift best practices.
