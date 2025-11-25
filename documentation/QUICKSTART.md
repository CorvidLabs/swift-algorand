# Quick Start Guide

## Test the SDK in 5 Minutes

### Option 1: LocalNet (Easiest - No Registration)

```bash
# 1. Start local Algorand network
./scripts/start-localnet.sh

# 2. Run the interactive example
ALGORAND_NETWORK=localnet swift run algorand-example

# 3. Send a test transaction
ALGORAND_NETWORK=localnet SEND_TRANSACTION=1 swift run algorand-example

# 4. Run integration tests
ALGORAND_NETWORK=localnet swift test

# 5. Stop localnet
docker-compose down
```

### Option 2: TestNet (Public Test Network)

```bash
# 1. Create account and get test funds
./scripts/test-testnet.sh

# The script will:
# - Create a new account
# - Show you where to get free test ALGO
# - Let you send test transactions once funded
```

## What You Can Do

### Create an Account

```swift
import Algorand

let account = Account()
print("Address: \(account.address)")
print("Mnemonic: \(account.mnemonic)")  // Save this!
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
    .amount(MicroAlgos(algos: 1.0))
    .params(params)
    .build()

let signedTxn = try SignedTransaction.sign(transaction, with: account)
let txID = try await algod.sendTransaction(signedTxn)

// Wait for confirmation
let confirmed = try await algod.waitForConfirmation(transactionID: txID)
print("Confirmed in round \(confirmed.confirmedRound!)")
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
- **Faucet**: https://bank.testnet.algorand.network/
- **Explorer**: https://testnet.algoexplorer.io/

### MainNet (Real Tokens - Use Carefully!)
- **Algod**: `https://mainnet-api.algonode.cloud`
- **Indexer**: `https://mainnet-idx.algonode.cloud`
- **Explorer**: https://algoexplorer.io/

### LocalNet (Your Machine)
- **Algod**: `http://localhost:4001`
- **Indexer**: `http://localhost:8980`
- **Token**: `aaaa...` (64 'a's)

## Common Tasks

### Get Test Funds (TestNet)

1. Create account: `ALGORAND_NETWORK=testnet swift run algorand-example`
2. Copy your address
3. Visit https://bank.testnet.algorand.network/
4. Paste address and click "Dispense"
5. Wait ~5 seconds

### Import Existing Account

```bash
export ALGORAND_MNEMONIC="your 25 word mnemonic phrase here"
ALGORAND_NETWORK=testnet swift run algorand-example
```

### Run All Tests

```bash
# Unit tests (no network)
swift test --filter '!IntegrationTests'

# Integration tests (requires network)
ALGORAND_NETWORK=localnet swift test --filter IntegrationTests
```

## Troubleshooting

### "Docker is not running"
- Open Docker Desktop
- Wait for it to start
- Try again

### "Account has no funds"
- **TestNet**: Get funds from https://bank.testnet.algorand.network/
- **LocalNet**: See [TESTING.md](TESTING.md) for funding instructions

### "Connection refused"
- **LocalNet**: Run `docker-compose up -d` first
- **TestNet**: Check your internet connection

## Next Steps

- Read the full [README.md](../README.md) for detailed API docs
- See [TESTING.md](TESTING.md) for comprehensive testing guide
- Check [SECURITY.md](SECURITY.md) for best practices
- Browse [example code](../Sources/AlgorandExample/) for more samples

## Need Help?

1. Check [TESTING.md](TESTING.md) for detailed troubleshooting
2. Review the API documentation in [README.md](../README.md)
3. Look at working examples in [Sources/AlgorandExample/](../Sources/AlgorandExample/)
4. Open an issue on GitHub
