# Getting Started

Create accounts, send payments, and interact with the Algorand blockchain.

## Overview

This guide walks through the core workflows of the swift-algorand SDK: creating accounts, configuring network connections, building transactions, and submitting them to the network.

## Add the Dependency

Add swift-algorand to your `Package.swift`. Pin to the `0.3.x` line: `from:` means `.upToNextMajor`, which would accept a `0.4.0` that, pre-1.0, may break your build.

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", .upToNextMinor(from: "0.3.2"))
]
```

Then add the `Algorand` product to your target's dependencies. The package is named `swift-algorand`, so the product must be named through `.product(name:package:)`:

```swift
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "Algorand", package: "swift-algorand")
    ]
)
```

## Create an Account

Generate a new account with a random private key:

```swift
import Algorand

let account = try Account()
print(account.address) // 58-character Algorand address
```

Restore an account from a 25-word mnemonic. Only the canonical spelling of a key is accepted, as in the official SDKs; the other 255 spellings that decode to the same key throw `AlgorandError.invalidMnemonic`:

```swift
let account = try Account(
    mnemonic: "abandon abandon abandon ... about"
)
```

Export the mnemonic for backup:

```swift
let words = try account.mnemonic()
```

## Configure a Network Client

Connect to a local Algorand node. The well-known configurations throw, because the SDK never force-unwraps a URL:

```swift
let config = try AlgorandConfiguration.localnet()
let client = AlgodClient(
    baseURL: config.algodURL,
    apiToken: config.apiToken
)
```

Or connect to TestNet:

```swift
let config = try AlgorandConfiguration.testnet()
let client = AlgodClient(
    baseURL: config.algodURL,
    apiToken: "your-api-token"
)
```

A string base URL that is not an absolute `http` or `https` URL is rejected with `AlgorandError.invalidURL`:

```swift
let client = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")
```

## Send a Payment

Build and submit a payment transaction. `Address(string:)` accepts only the canonical 58-character rendering, and `MicroAlgos(checkedAlgos:)` throws on NaN, negative, or out-of-range amounts instead of trapping:

```swift
// Get current network parameters
let params = try await client.transactionParams()

// Build the transaction
let payment = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(try Address(string: "RECIPIENT..."))
    .amount(try MicroAlgos(checkedAlgos: 1.0))
    .params(params)
    .build()

// Sign and send
let signed = try SignedTransaction.sign(payment, with: account)
let txID = try await client.sendTransaction(signed)

// Wait for confirmation. A 404 from the node for a transaction it has not seen yet is
// treated as "not yet", and polling continues until the timeout elapses.
let confirmed = try await client.waitForConfirmation(
    transactionID: txID,
    timeout: 10
)
```

## Simulate Before Sending

`simulateTransaction` posts the signed group to `POST /v2/transactions/simulate` as MessagePack and decodes the result. A fee or well-formedness failure arrives as HTTP 200 with the detail in `failureMessage`, so check it:

```swift
let group = try SimulateRequestTransactionGroup(signedTransactions: [signed])
let result = try await client.simulateTransaction(SimulateRequest(txnGroups: [group]))
if let failure = result.txnGroups.first?.failureMessage {
    print("Simulation failed: \(failure)")
}
```

## Work with Assets

Create an Algorand Standard Asset (ASA):

```swift
let assetParams = AssetParams(
    total: 1_000_000,
    decimals: 6,
    unitName: "COIN",
    assetName: "My Token",
    manager: account.address
)

let createTx = AssetCreateTransaction(
    sender: account.address,
    assetParams: assetParams,
    fee: MicroAlgos(1000),
    firstValid: params.lastRound,
    lastValid: params.lastRound + 1000,
    genesisID: params.genesisID,
    genesisHash: params.genesisHash
)
```

Convert a human-readable amount to base units with `baseUnits(for:)`, which rounds to the nearest base unit and throws `AmountError` rather than trapping on bad input:

```swift
let baseUnits = try assetParams.baseUnits(for: 12.5)  // 12_500_000 with 6 decimals
```

Opt in to receive an asset:

```swift
let optIn = AssetOptInTransaction(
    sender: account.address,
    assetID: 12345,
    fee: MicroAlgos(1000),
    firstValid: params.lastRound,
    lastValid: params.lastRound + 1000,
    genesisID: params.genesisID,
    genesisHash: params.genesisHash
)
```

## Atomic Transaction Groups

Group multiple transactions for atomic execution:

```swift
let group = try AtomicTransactionGroupBuilder()
    .add(payment1)
    .add(payment2)
    .build()

let signed = try SignedAtomicTransactionGroup.sign(
    group,
    with: [0: sender1, 1: sender2]
)

let txID = try await client.sendTransactionGroup(signed)
```

## Query the Indexer

Search historical data with the Indexer client. `indexerURL` is optional, because a custom configuration may not have one:

```swift
guard let indexerURL = config.indexerURL else {
    throw AlgorandError.invalidURL("This configuration has no indexer")
}
let indexer = IndexerClient(baseURL: indexerURL)

// Look up an account
let info = try await indexer.account(account.address)

// Search transactions
let txns = try await indexer.searchTransactions(
    address: account.address,
    limit: 10
)
```
