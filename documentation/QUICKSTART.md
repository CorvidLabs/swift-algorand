# Quick Start Guide

This package ships one library product, `Algorand`, and no executables. Everything here is
either a `swift test` invocation against this repository or code you paste into your own
package.

## Run the test suite in 5 minutes

```bash
# Unit tests only - no network, no Docker. 77 tests.
swift test --skip IntegrationTest --skip ProofOfWorkTest

# The whole suite the way CI runs it: 98 tests, 20 skipped, 0 failures.
CI=true swift test
```

### Add a local network

The integration tests only do real work when `ALGORAND_NETWORK=localnet` and `CI` is unset.

```bash
# 1. Start a local Algorand network
./scripts/start-localnet.sh

# 2. Run the suite against it
ALGORAND_NETWORK=localnet swift test

# 3. Stop it when you are done
docker compose down
```

Read-only integration tests pass against any local node on the default ports. The mutating
ones have extra requirements documented in [TESTING.md](TESTING.md); read that before
treating a failure there as an SDK bug.

## A complete program you can run

This is the fastest way to exercise TestNet. The test suite deliberately does not touch
TestNet or MainNet, so a small program of your own is the supported path.

Create a package:

```bash
mkdir algorand-testnet-check && cd algorand-testnet-check
swift package init --type executable

# The template ships a stub with an @main type. Remove it - the program below is
# top-level code, which Swift only allows in a file named main.swift.
rm Sources/algorand-testnet-check/algorand_testnet_check.swift
rm -rf Tests
```

Set `Package.swift` to:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "algorand-testnet-check",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/CorvidLabs/swift-algorand.git", .upToNextMinor(from: "0.4.0"))
    ],
    targets: [
        .executableTarget(
            name: "algorand-testnet-check",
            dependencies: [.product(name: "Algorand", package: "swift-algorand")]
        )
    ]
)
```

Put this in `Sources/algorand-testnet-check/main.swift`:

```swift
@preconcurrency import Foundation
import Algorand

// The SDK never reads environment variables. `MY_APP_ALGORAND_MNEMONIC` belongs to this
// program, and using an environment variable for a key is only acceptable on TestNet.
private func loadAccount() throws -> Account {
    guard let mnemonic = ProcessInfo.processInfo.environment["MY_APP_ALGORAND_MNEMONIC"] else {
        let created = try Account()
        let phrase = try created.mnemonic()
        print("No MY_APP_ALGORAND_MNEMONIC set. Created a new account:")
        print("  Address:  \(created.address)")
        print("  Mnemonic: \(phrase)")
        print("Fund it at https://bank.testnet.algorand.network/ then re-run with:")
        print("  export MY_APP_ALGORAND_MNEMONIC=\"\(phrase)\"")
        return created
    }
    return try Account(mnemonic: mnemonic)
}

let account = try loadAccount()
let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")

let info = try await algod.accountInformation(account.address)
let balance = MicroAlgos(info.amount)
print("Balance: \(balance.algos) ALGO")

guard balance.value > 101_000 else {
    print("Not enough ALGO to send. Fund \(account.address) and try again.")
    exit(0)
}

let params = try await algod.transactionParams()
let receiver = try Address(
    string: ProcessInfo.processInfo.environment["MY_APP_RECEIVER"] ?? account.address.description
)

let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(MicroAlgos(1_000))
    .params(params)
    .note("swift-algorand testnet check")
    .build()

let signed = try SignedTransaction.sign(transaction, with: account)
let txID = try await algod.sendTransaction(signed)
print("Submitted: \(txID)")

let confirmed = try await algod.waitForConfirmation(transactionID: txID)
if let round = confirmed.confirmedRound {
    print("Confirmed in round \(round)")
    print("Inspect it at https://lora.algokit.io/testnet/transaction/\(txID)")
} else {
    print("Not confirmed within the wait window; check \(txID) later.")
}
```

Then:

```bash
# First run: creates an unfunded account and prints the mnemonic and dispenser link.
swift run

# Fund the printed address, export the mnemonic it gave you, then run again to send.
export MY_APP_ALGORAND_MNEMONIC="the 25 words printed above"
swift run
```

The default receiver is the sender itself, which is a safe self-payment. Set
`MY_APP_RECEIVER` to send somewhere else.

## What You Can Do

### Create an Account

```swift
import Algorand

let account = try Account()
print("Address: \(account.address)")

let mnemonic = try account.mnemonic()  // throwing method, not a property
print("Mnemonic: \(mnemonic)")  // Save this!
```

### Check Balance

```swift
let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")
let info = try await algod.accountInformation(account.address)
print("Balance: \(MicroAlgos(info.amount).algos) ALGO")
```

### Send a Payment

```swift
let params = try await algod.transactionParams()

let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiverAddress)
    .amount(try MicroAlgos(checkedAlgos: 1.0))
    .params(params)
    .build()

let signedTxn = try SignedTransaction.sign(transaction, with: account)
let txID = try await algod.sendTransaction(signedTxn)

// Wait for confirmation. `confirmedRound` is optional.
let confirmed = try await algod.waitForConfirmation(transactionID: txID)
if let round = confirmed.confirmedRound {
    print("Confirmed in round \(round)")
}
```

### Query Transactions

```swift
let indexer = try IndexerClient(baseURL: "https://testnet-idx.algonode.cloud")
let txns = try await indexer.searchTransactions(address: account.address, limit: 10)

for txn in txns.transactions {
    print("Transaction: \(txn.id)")
}
```

## Network URLs

### TestNet (Free Test Tokens)
- **Algod**: `https://testnet-api.algonode.cloud`
- **Indexer**: `https://testnet-idx.algonode.cloud`
- **Dispenser**: https://bank.testnet.algorand.network/
- **Explorer**: https://lora.algokit.io/testnet

### MainNet (Real Tokens - Use Carefully!)
- **Algod**: `https://mainnet-api.algonode.cloud`
- **Indexer**: `https://mainnet-idx.algonode.cloud`
- **Explorer**: https://allo.info/

### LocalNet (Your Machine)
- **Algod**: `http://localhost:4001`
- **Indexer**: `http://localhost:8980`
- **Token**: 64 `a` characters

`try AlgorandConfiguration.localnet()`, `.testnet()`, and `.mainnet()` return these values if
you would rather not hardcode them; they throw rather than force-unwrap the endpoint literals.

## Common Tasks

### Get Test Funds (TestNet)

1. Run the program above once; it prints a fresh address.
2. Copy the address.
3. Visit https://bank.testnet.algorand.network/
4. Paste the address and click "Dispense".
5. Wait ~5 seconds, then run again.

### Import an Existing Account

```swift
let account = try Account(mnemonic: "your 25 word mnemonic phrase here")
```

Read the mnemonic from the Keychain, a secret manager, or - on TestNet only - an
environment variable your program defines. The SDK reads no environment variables itself.

### Run All Tests

```bash
# Unit tests only (no network) - 77 tests
swift test --skip IntegrationTest --skip ProofOfWorkTest

# Integration tests (requires a local node on ports 4001 and 8980)
ALGORAND_NETWORK=localnet swift test --filter 'AlgorandTests.IntegrationTests'
```

`--filter` and `--skip` take regular expressions in `<test-target>.<test-case>/<test>` form.
There is no negation syntax; use `--skip` to exclude.

## Troubleshooting

### "Docker is not running"
- Open Docker Desktop
- Wait for it to start
- Try again

### "Account has no funds"
- **TestNet**: Get funds from https://bank.testnet.algorand.network/
- **LocalNet**: See [TESTING.md](TESTING.md) for funding instructions

### "Connection refused"
- **LocalNet**: Run `docker compose up -d` first
- **TestNet**: Check your internet connection

### Integration tests all report "skipped"
That is the designed behaviour unless `ALGORAND_NETWORK=localnet` and `CI` is unset. See
[TESTING.md](TESTING.md).

## Next Steps

- Read the full [README.md](../README.md) for detailed API docs
- See [TESTING.md](TESTING.md) for how the suite is gated
- Check [SECURITY.md](SECURITY.md) for key-handling best practices

## Need Help?

1. Check [TESTING.md](TESTING.md) for detailed troubleshooting
2. Review the API documentation in [README.md](../README.md)
3. Open an issue on GitHub
