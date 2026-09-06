# swift-algorand

[![macOS](https://img.shields.io/github/actions/workflow/status/CorvidLabs/swift-algorand/macOS.yml?label=macOS&branch=main)](https://github.com/CorvidLabs/swift-algorand/actions/workflows/macOS.yml)
[![Ubuntu](https://img.shields.io/github/actions/workflow/status/CorvidLabs/swift-algorand/ubuntu.yml?label=Ubuntu&branch=main)](https://github.com/CorvidLabs/swift-algorand/actions/workflows/ubuntu.yml)
[![License](https://img.shields.io/github/license/CorvidLabs/swift-algorand)](https://github.com/CorvidLabs/swift-algorand/blob/main/LICENSE)
[![Version](https://img.shields.io/github/v/release/CorvidLabs/swift-algorand)](https://github.com/CorvidLabs/swift-algorand/releases)

> **Pre-1.0 Notice**: This SDK is under active development. The API may change between minor versions until 1.0. This documentation targets the `0.4.x` line.

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
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", .upToNextMinor(from: "0.4.0"))
]
```

`.upToNextMinor` pins to the `0.4.x` line. This is deliberate: SwiftPM's `from:` means
`.upToNextMajor`, so `from: "0.4.0"` would accept any version below `1.0.0` — including a
`0.5.0` that, per the pre-1.0 notice above, may break your build. Use `from:` only once 1.0
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
    .amount(try MicroAlgos(checkedAlgos: 1.0))  // 1 ALGO
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

`Address(string:)` accepts only the canonical form, exactly as go-algorand's
`UnmarshalChecksumAddress` does: 58 uppercase base32 characters whose decoded bytes re-encode to
the identical string. A lowercase address, or one whose final character carries stray bits past
the 36 decoded bytes, is rejected with `AlgorandError.invalidAddress` even though its checksum
passes, and `description` is always the canonical rendering.

### Mnemonics

`Mnemonic.decode` and `Account(mnemonic:)` are strict: the 24 key words carry eight spare bits
beyond the 32-byte key, and only the spelling that leaves them zero is accepted, which is the
check py-algorand-sdk and go-algorand make. The other 255 spellings of the same key throw
`AlgorandError.invalidMnemonic`. Every mnemonic this SDK generates is canonical.

### Amounts

Amounts are type-safe with `MicroAlgos`. The `UInt64` operators trap on overflow and on a zero
divisor, and `UInt64(_: Double)` traps on NaN, negative, and out-of-range input; a trap cannot be
caught, so the checked forms throw `AmountError` instead:

```swift
// From microAlgos (1 ALGO = 1,000,000 microAlgos)
let fromMicroAlgos = MicroAlgos(1_000_000)

// From Algos, rounded to the nearest microAlgo; throws on NaN, negative, or > UInt64 input
let fromAlgos = try MicroAlgos(checkedAlgos: 1.0)

// Checked arithmetic
let total = try fromAlgos.adding(MicroAlgos(2_000_000))
let doubled = try fromAlgos.multiplied(by: 2)   // AmountError.overflow past UInt64.max
let half = try fromAlgos.divided(by: 2)         // AmountError.divisionByZero for 0
let change = try total.subtracting(fromAlgos)   // AmountError.overflow below zero
```

`MicroAlgos(algos:)` and the `+`, `-`, `*`, `/` operators still exist but are deprecated; the
deprecation message names the replacement. The same applies to `AssetParams.toBaseUnits(_:)`,
replaced by `baseUnits(for:)`, which rounds to the nearest base unit and throws rather than traps:

```swift
let params = AssetParams(total: 1_000_000, decimals: 2, unitName: "DEMO")
let baseUnits = try params.baseUnits(for: 10.5)  // 1050
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

Every transaction type also has an initializer and factories that take the suggested
parameters directly, so the validity window and genesis data never have to be copied by hand:

```swift
let optIn = try AssetOptInTransaction(sender: sender, assetID: 12345, params: params)
let call = try ApplicationCallTransaction.call(sender: sender, applicationID: 7, params: params)
```

### Fees (consensus v42)

Consensus v42 prices transactions by *usage*: every transaction owes one minimum fee, plus
0.0001 of a minimum fee per note byte beyond 1024, per application-argument byte beyond 2048,
and per program byte beyond 8192, plus two minimum fees for a Falcon-1024 envelope. The network
checks the **sum** of a group's fees against the **sum** of its members' usage, rounded up once.

Every builder and params-based initializer takes a `FeeStrategy`, `.minimum` by default:

```swift
// .minimum: the v42 requirement for this transaction alone, from params.minFee
let payment = try PaymentTransaction(sender: sender, receiver: receiver, amount: 1, params: params)

// .flat: exactly this fee, including 0 for a member another member pays for
let covered = try PaymentTransaction(sender: sender, receiver: receiver, amount: 1,
                                     fee: .flat(0), params: params)

// .suggested: the node's per-byte fee over the signed size, never below .minimum
let urgent = try PaymentTransactionBuilder().sender(sender).receiver(receiver)
    .amount(1).params(params).fee(.suggested).build()
```

A group is priced as a whole. Build the members with placeholder fees, ask the group what it
needs, and rebuild the paying member, because the fee is part of the bytes that are signed:

```swift
let drafts = try AtomicTransactionGroup(transactions: [payment, covered])
let required = try drafts.requiredFee(minFee: MicroAlgos(params.minFee))
let payer = try PaymentTransaction(sender: sender, receiver: receiver, amount: 1,
                                   fee: .flat(required), params: params)
let group = try AtomicTransactionGroup(transactions: [payer, covered])
let signed = try SignedAtomicTransactionGroup.sign(group, with: [0: account, 1: other])
try signed.checkFees(minFee: MicroAlgos(params.minFee))  // throws FeeError.insufficient
```

`Transaction.feeUsage()` and `SignedTransaction.feeUsage()` expose the usage itself, in
micro-units where `1_000_000` is one minimum fee, so a Falcon-1024 signer can be priced ahead of
signing with `PQScheme.falcon1024.feeUsage`. Fee arithmetic throws `FeeError.overflow` rather
than saturating. The header-field initializers keep a fixed default of
`AlgorandConsensus.v42.minimumFee` (1000 microAlgos) because they never see the network's
parameters.

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

### Simulating, confirming, and reading boxes

`simulateTransaction` posts the group to `POST /v2/transactions/simulate` as
`application/msgpack`, with each signed transaction's own canonical encoding spliced in, and
decodes the JSON response. A signature failure comes back as HTTP 400 (`AlgorandError.apiError`);
a well-formedness or fee failure comes back as HTTP 200 with the detail in `failureMessage`, so
check it:

```swift
let group = try SimulateRequestTransactionGroup(signedTransactions: [signedTxn])
let result = try await algod.simulateTransaction(SimulateRequest(txnGroups: [group]))
if let failure = result.txnGroups.first?.failureMessage {
    print("Simulation failed: \(failure)")
}
```

`waitForConfirmation` polls once per round and treats algod's `404` from
`GET /v2/transactions/pending/{id}` as "not seen yet" - the normal state for a round or two after
submission, and always the state when a load-balanced endpoint routed the submission elsewhere -
so it keeps polling until the transaction confirms or the timeout elapses, as js-algorand-sdk does.

`applicationBox(_:name:)` takes the raw box name as `Data` and builds the
`?name=b64:<base64>` query itself, percent-encoding the `+`, `/`, and `=` that base64 produces:

```swift
let box = try await algod.applicationBox(applicationID, name: Data("counter".utf8))
```

## Changes on the road to 1.0

The `0.3.x` line carried several APIs that trapped, accepted input the network rejects, or could
not work. They are corrected here; the source-breaking ones are listed so an upgrade is deliberate:

| Area | Change |
|---|---|
| `Address(string:)` | Canonical form only. Lowercase and stray-trailing-bit input now throws `invalidAddress`. |
| `Mnemonic.decode`, `Account(mnemonic:)` | Non-canonical spellings (the 33rd unpacked byte non-zero) now throw `invalidMnemonic`. |
| `MicroAlgos` | `+`, `-`, `*`, `/`, and `init(algos:)` are deprecated; use `adding`, `subtracting`, `multiplied(by:)`, `divided(by:)`, and `init(checkedAlgos:)`, which throw `AmountError`. |
| `AssetParams.toBaseUnits` | Deprecated; use `baseUnits(for:)`. |
| `MessagePackWriter`, `MessagePackValue`, `SHA512_256` | Internal. They were the wire format of one chain, not a general encoder or hash API. |
| `AlgorandError` | New case `invalidURL`; a bad client base URL reports it instead of `invalidAddress`. |
| `AlgorandConfiguration` | `init(network:)`, `localnet()`, `testnet()`, and `mainnet()` throw instead of force-unwrapping the endpoint literals; `custom` does not. |
| `AlgodClient.applicationBox` | Takes the box name as `Data`; the previous version percent-encoded its own `?` and could never reach the endpoint. |
| `AlgodClient.simulateTransaction` | Posts MessagePack; `SimulateRequestTransactionGroup.txns` is `[Data]` (canonical signed encodings) with an `init(signedTransactions:)`. The previous JSON body was never accepted by algod. |
| `AlgodClient.waitForConfirmation` | Keeps polling through a `404`; throws `invalidTransaction` if `timeout` would overflow the round counter. |
| `PendingTransaction.txn`, `TransactionData` | Removed. The empty `TransactionData` decoded the node's echo of your own submission and dropped every field; the fields a caller acts on (`confirmedRound`, `poolError`, `assetIndex`, `applicationIndex`) remain. |
| `BlockResponse` | Was an empty struct; now carries the block header and the block's transactions. |
| `IndexerAsset.params` | Typed as `AssetParamsResponse`, the model algod already returns, with a deprecated `IndexerAsset.AssetParams` typealias. |
| `Account` | Stores its key as `Curve25519.Signing.PrivateKey` rather than a `Data` copy of the seed; see [SECURITY.md](SECURITY.md). |

Transaction encodings are unchanged: the golden-vector suites pass byte-for-byte.

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
hardcode endpoints. The well-known factories throw, because Foundation offers no non-failable
`http` URL constructor and the SDK does not force-unwrap:

```swift
let configuration = try AlgorandConfiguration.testnet()
let algod = AlgodClient(baseURL: configuration.algodURL, apiToken: configuration.apiToken)
```

A string base URL that is not an absolute `http` or `https` URL is rejected with
`AlgorandError.invalidURL` by `AlgodClient(baseURL:)` and `IndexerClient(baseURL:)`.

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

Setting `CI` makes the integration suites skip themselves. This executes 98 XCTest tests with 20
skipped and 0 failures, followed by the Swift Testing suites (129 tests in 7 suites). Compiling
the legacy XCTest suites prints deprecation warnings for `MicroAlgos(algos:)`, the `MicroAlgos`
operators, and `AssetParams.toBaseUnits`, which those suites exercise on purpose; the library
itself builds warning-free.

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
