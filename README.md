# swift-algorand

[![macOS](https://img.shields.io/github/actions/workflow/status/CorvidLabs/swift-algorand/macOS.yml?label=macOS&branch=main)](https://github.com/CorvidLabs/swift-algorand/actions/workflows/macOS.yml)
[![Ubuntu](https://img.shields.io/github/actions/workflow/status/CorvidLabs/swift-algorand/ubuntu.yml?label=Ubuntu&branch=main)](https://github.com/CorvidLabs/swift-algorand/actions/workflows/ubuntu.yml)
[![License](https://img.shields.io/github/license/CorvidLabs/swift-algorand)](https://github.com/CorvidLabs/swift-algorand/blob/main/LICENSE)
[![Version](https://img.shields.io/github/v/release/CorvidLabs/swift-algorand)](https://github.com/CorvidLabs/swift-algorand/releases)

> **Pre-1.0 Notice**: This SDK is under active development. The API may change between minor versions until 1.0. The latest release is in the `0.3.x` line.

A modern Swift SDK for the Algorand blockchain. Built with Swift 6 and async/await.

## Features

- **Swift 6** - Built with the latest Swift concurrency features
- **Type-Safe** - Leveraging Swift's type system for safe blockchain interactions
- **Modern Async/Await** - No callbacks, just clean async code
- **Multi-Platform** - macOS 11+ and Linux are built and tested in CI. iOS 15+, tvOS 15+,
  watchOS 8+ and visionOS 1+ are declared minimums that CI does not currently build
- **Pure Swift** - No SwiftUI dependencies, just core blockchain functionality

## Installation

### Swift Package Manager

Add Algorand to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", .upToNextMinor(from: "0.3.2"))
]
```

`.upToNextMinor` pins to the `0.3.x` line. This is deliberate: SwiftPM's `from:` means
`.upToNextMajor`, so `from: "0.3.2"` would accept any version below `1.0.0` — including a
`0.4.0` that, per the pre-1.0 notice above, may break your build. Use `from:` only once 1.0
has shipped.

Then add the dependency to your target:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "Algorand", package: "swift-algorand")
    ]
)
```

Or add it via Xcode:
1. File > Add Package Dependencies
2. Enter: `https://github.com/CorvidLabs/swift-algorand.git`

The package vends a single library product, `Algorand`. It ships no executables.

## Documentation

- **[Getting Started](documentation/GETTING_STARTED.md)** - Step-by-step guide for your first transaction
- **[Quick Start](documentation/QUICKSTART.md)** - Get a working program in 5 minutes
- **[Testing Guide](documentation/TESTING.md)** - How the test suite is gated and how to run it
- **[Security Best Practices](documentation/SECURITY.md)** - Guidance for production use
- **[Security Policy](SECURITY.md)** - How to report a vulnerability
- **[Contributing](CONTRIBUTING.md)** - How to contribute to the project

## Quick Start

### Creating an Account

```swift
import Algorand

// Create a new random account. `Account()` can throw - key generation uses the platform CSPRNG.
let account = try Account()
print("Address: \(account.address)")

// The mnemonic is derived on demand by a throwing method, not stored as a property.
let mnemonic = try account.mnemonic()
print("Mnemonic: \(mnemonic)")  // Store this securely. Never commit it.

// Import an existing account from a 25-word mnemonic
let existingAccount = try Account(mnemonic: mnemonic)
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

// Wait for confirmation. `confirmedRound` is optional - never force unwrap it.
let confirmed = try await algod.waitForConfirmation(transactionID: txID)
if let round = confirmed.confirmedRound {
    print("Confirmed in round: \(round)")
} else {
    print("Submitted but not yet confirmed")
}
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

// Search for assets. `limit` precedes `name` in the declaration, so it comes first here.
let assets = try await indexer.searchAssets(
    limit: 5,
    name: "USDC"
)

for asset in assets.assets {
    print("Asset \(asset.index): \(asset.params.name ?? "Unknown")")
}
```

## Core Concepts

### Addresses

Algorand addresses are represented by the `Address` type. Both initializers throw:

```swift
// From string
let fromString = try Address(string: "YOUR_ADDRESS_HERE")

// From 32 raw public key bytes
let fromBytes = try Address(bytes: publicKeyBytes)
```

### Amounts

Amounts are type-safe with `MicroAlgos`:

```swift
// From microAlgos (1 ALGO = 1,000,000 microAlgos)
let fromMicroAlgos = MicroAlgos(1_000_000)

// From Algos
let fromAlgos = MicroAlgos(algos: 1.0)

// Arithmetic operations
let total = MicroAlgos(algos: 1.0) + MicroAlgos(algos: 2.0)
let doubled = fromAlgos * 2  // scalar multiplication takes a UInt64
```

### Transactions

Build transactions using the builder pattern. Every builder method returns a new builder,
and `build()` throws when a required field is missing:

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

When the signing account is not the transaction's sender, the envelope carries the signer as
`sgnr` automatically, which is how a rekeyed account is spent. Any `TransactionSigner` can sign
the same way; `Account` conforms, and `Transaction.bytesToSign(groupID:)` exposes the exact
unhashed preimage for an external key store.

```swift
let signedTxn = try await account.sign(transaction)
```

#### Post-quantum accounts (consensus v42)

A native post-quantum account is authorized by a Falcon-1024 proof in the `pqsig` envelope. The
SDK derives the account's address and canonical salt from the public key, builds the envelope, and
checks that the proof authorizes the sender; the signature itself comes from a callback, because
no Falcon implementation is bundled (the official Python and JavaScript SDKs bundle none either).

```swift
let signer = try PQSigner(publicKey: falconPublicKey) { bytes in
    try await falconBackend.sign(bytes)  // det1024 over the exact bytes handed in
}
print(signer.address)  // SHA512_256("PQA" || "f1" || salt || publicKey)
let signedTxn = try await signer.sign(transaction)
```

## Architecture

The SDK is organized into several key components:

- **Core Types**: `Address`, `MicroAlgos`, `Account`
- **Transactions**: `PaymentTransaction`, `AssetTransaction`, `ApplicationTransaction`,
  `KeyRegistrationTransaction`, `AtomicTransactionGroup`, `SignedTransaction`
- **Clients**: `AlgodClient` (node interaction), `IndexerClient` (queries)
- **Mnemonics**: BIP-39 wordlist based 25-word mnemonic encoding and decoding

`AlgodClient` and `IndexerClient` are `actor` types and expose only `async` methods. Each
client owns a dedicated `URLSession` with a 30s per-request and 60s per-resource timeout,
both configurable at init.

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

`AlgorandConfiguration` bundles a network with its URLs and token if you would rather not
hardcode endpoints:

```swift
let configuration = AlgorandConfiguration.testnet()
let algod = AlgodClient(baseURL: configuration.algodURL, apiToken: configuration.apiToken)
```

## Testing

### Unit tests (no network, no Docker)

```bash
swift test --skip IntegrationTest --skip ProofOfWorkTest
```

Runs 77 tests covering addresses, mnemonics, MicroAlgos arithmetic, SHA-512/256, and
offline construction and encoding of every transaction type the SDK models: `pay`,
`keyreg`, `acfg`, `axfer`, `afrz`, `appl`, and atomic groups.

### Full suite the way CI runs it

```bash
CI=true swift test
```

Setting `CI` makes the integration suites skip themselves. This executes 98 tests with 20
skipped and 0 failures.

### Integration tests against a local node

```bash
ALGORAND_NETWORK=localnet swift test
```

`ALGORAND_NETWORK` is the only network variable the test suite reads, and every integration
test is gated on it being `localnet`. Pointing it at `testnet` or `mainnet` makes the tests
run and immediately skip, so it is not a way to exercise those networks. The mutating
integration tests additionally shell out to Docker to fund accounts and have further
environment requirements. See the [Testing Guide](documentation/TESTING.md) before relying
on them.

To exercise TestNet or MainNet, write a small program against the library - the
[Quick Start guide](documentation/QUICKSTART.md) has a complete one you can copy.

## Requirements

- Swift 6.0+
- macOS 11.0+ and Linux (CI-verified); iOS 15.0+ / tvOS 15.0+ / watchOS 8.0+ / visionOS 1.0+ (declared, not built in CI)
- Linux (with Swift 6.0+)
- Docker (optional, only for the LocalNet integration tests)

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Resources

- [Algorand Developer Portal](https://dev.algorand.co/)
- [Algorand REST API reference](https://dev.algorand.co/reference/rest-api/overview/)
- [TestNet dispenser](https://bank.testnet.algorand.network/)
- [Lora block explorer](https://lora.algokit.io/testnet)

## Credits

Built with inspiration from the Swift Algorand SDK ecosystem and modern Swift best practices.
