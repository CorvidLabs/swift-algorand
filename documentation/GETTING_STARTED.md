# Getting Started with Algorand SDK

This guide will help you get started with the Algorand Swift SDK.

> The package is pre-1.0. The API may change between minor versions until 1.0.

## Installation

Add the package to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/CorvidLabs/swift-algorand.git", from: "0.3.2")
]
```

Then add the library product to the target that uses it:

```swift
.executableTarget(
    name: "YourApp",
    dependencies: [
        .product(name: "Algorand", package: "swift-algorand")
    ]
)
```

`Algorand` is the only product this package vends. There is no bundled executable, so
everything below is code you run from your own target.

## Your First Transaction

### Step 1: Create or Import an Account

```swift
import Algorand

// Option 1: Create a new account. Generation uses the platform CSPRNG and can throw.
let account = try Account()

// `mnemonic()` is a throwing method, not a stored property.
let phrase = try account.mnemonic()
print("Save this mnemonic: \(phrase)")

// Option 2: Import an existing account
let imported = try Account(mnemonic: phrase)
```

### Step 2: Fund Your Account

For TestNet, use the [Algorand dispenser](https://bank.testnet.algorand.network/) to get
test ALGO. Paste the address printed above and dispense; funds arrive within a few seconds.

### Step 3: Connect to a Node

```swift
let algod = try AlgodClient(
    baseURL: "https://testnet-api.algonode.cloud"
)
```

The string initializer throws if the URL is malformed. There is also a non-throwing
initializer that takes a `URL` directly.

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

// Wait for confirmation. `confirmedRound` is optional - unwrap it, never force it.
let confirmed = try await algod.waitForConfirmation(transactionID: txID)
if let round = confirmed.confirmedRound {
    print("Confirmed in round: \(round)")
} else {
    print("Submitted but not confirmed within the wait window")
}
```

`waitForConfirmation` polls for up to 10 rounds by default; pass `timeout:` to change that.
It throws rather than returning if the transaction hits a pool error.

## Next Steps

- Check out the main [README](../README.md) for a full API overview
- Copy the complete runnable program in the [Quick Start guide](QUICKSTART.md)
- Understand [Security Best Practices](SECURITY.md)
- Review the [Testing Guide](TESTING.md) to see how the suite is gated

## Common Patterns

### Error Handling

Every SDK failure is an `AlgorandError`. Its cases are `invalidAddress`, `invalidMnemonic`,
`invalidTransaction`, `networkError`, `encodingError`, `decodingError`, `invalidResponse`,
and `apiError(statusCode:message:)`.

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
