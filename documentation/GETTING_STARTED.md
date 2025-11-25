# Getting Started with Algorand SDK

This guide will help you get started with the Algorand Swift SDK.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", from: "1.0.0")
]
```

## Your First Transaction

### Step 1: Create or Import an Account

```swift
import Algorand

// Option 1: Create a new account
let account = Account()
print("Save this mnemonic: \(account.mnemonic)")

// Option 2: Import existing account
let mnemonic = "your 25 word mnemonic phrase here"
let account = try Account(mnemonic: mnemonic)
```

### Step 2: Fund Your Account

For TestNet, use the [Algorand Dispenser](https://bank.testnet.algorand.network/) to get test ALGO.

### Step 3: Connect to a Node

```swift
let algod = try AlgodClient(
    baseURL: "https://testnet-api.algonode.cloud"
)
```

### Step 4: Check Your Balance

```swift
let accountInfo = try await algod.accountInformation(account.address)
print("Balance: \(MicroAlgos(accountInfo.amount).algos) ALGO")
```

### Step 5: Send a Transaction

```swift
// Get transaction parameters
let params = try await algod.transactionParams()

// Create receiver address
let receiver = try Address(string: "RECEIVER_ADDRESS_HERE")

// Build transaction
let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(MicroAlgos(algos: 1.0))
    .params(params)
    .note("My first transaction!")
    .build()

// Sign transaction
let signedTxn = try SignedTransaction.sign(transaction, with: account)

// Submit to network
let txID = try await algod.sendTransaction(signedTxn)
print("Transaction ID: \(txID)")

// Wait for confirmation
let confirmedTxn = try await algod.waitForConfirmation(transactionID: txID)
print("Confirmed in round: \(confirmedTxn.confirmedRound!)")
```

## Next Steps

- Check out the main [README](../README.md) for full API overview
- Run the examples in [Sources/AlgorandExample](../Sources/AlgorandExample)
- Understand [Security Best Practices](SECURITY.md)
- Review [Testing Guide](TESTING.md) for test setup

## Common Patterns

### Error Handling

```swift
do {
    let txID = try await algod.sendTransaction(signedTxn)
    print("Success: \(txID)")
} catch let error as AlgorandError {
    switch error {
    case .networkError(let message):
        print("Network error: \(message)")
    case .apiError(let statusCode, let message):
        print("API error \(statusCode): \(message)")
    default:
        print("Error: \(error)")
    }
}
```

### Checking Transaction Status

```swift
// Get pending transaction info
let pending = try await algod.pendingTransaction(txID)

if let confirmedRound = pending.confirmedRound {
    print("Confirmed in round \(confirmedRound)")
} else {
    print("Transaction still pending")
}
```

### Using the Indexer

```swift
let indexer = try IndexerClient(
    baseURL: "https://testnet-idx.algonode.cloud"
)

// Get account transactions
let txns = try await indexer.searchTransactions(
    address: account.address,
    limit: 10
)

for txn in txns.transactions {
    print("Transaction: \(txn.id)")
}
```
