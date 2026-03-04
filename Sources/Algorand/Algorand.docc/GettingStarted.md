# Getting Started

Create accounts, send payments, and interact with the Algorand blockchain.

## Overview

This guide walks through the core workflows of the swift-algorand SDK: creating accounts, configuring network connections, building transactions, and submitting them to the network.

## Add the Dependency

Add swift-algorand to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", from: "0.1.0")
]
```

Then add `"Algorand"` to your target's dependencies:

```swift
.target(
    name: "MyApp",
    dependencies: ["Algorand"]
)
```

## Create an Account

Generate a new account with a random private key:

```swift
import Algorand

let account = try Account()
print(account.address) // 58-character Algorand address
```

Restore an account from a 25-word mnemonic:

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

Connect to a local Algorand node:

```swift
let config = AlgorandConfiguration.localnet()
let client = AlgodClient(
    baseURL: config.algodURL,
    apiToken: config.apiToken
)
```

Or connect to TestNet:

```swift
let config = AlgorandConfiguration.testnet()
let client = AlgodClient(
    baseURL: config.algodURL,
    apiToken: "your-api-token"
)
```

## Send a Payment

Build and submit a payment transaction:

```swift
// Get current network parameters
let params = try await client.transactionParams()

// Build the transaction
let payment = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(try Address(string: "RECIPIENT..."))
    .amount(MicroAlgos(algos: 1.0))
    .params(params)
    .build()

// Sign and send
let signed = try SignedTransaction.sign(transaction: payment, with: account)
let txID = try await client.sendTransaction(signed.encode())

// Wait for confirmation
let confirmed = try await client.waitForConfirmation(
    transactionID: txID,
    timeout: 10
)
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

let txID = try await client.sendTransactionGroup(signed.encode())
```

## Query the Indexer

Search historical data with the Indexer client:

```swift
let indexer = IndexerClient(
    baseURL: config.indexerURL!
)

// Look up an account
let info = try await indexer.account(account.address.description)

// Search transactions
let txns = try await indexer.searchTransactions(
    address: account.address.description,
    limit: 10
)
```
