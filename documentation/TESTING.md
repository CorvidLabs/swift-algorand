# Testing Guide

This guide explains how to test the Algorand Swift SDK against different networks.

## Quick Start

### 1. Unit Tests (No Network Required)

```bash
swift test
```

Runs all unit tests (Address, MicroAlgos, Account, Mnemonic) - no network connection needed.

## Network Testing

### LocalNet (Recommended for Development)

LocalNet runs a private Algorand blockchain on your machine, perfect for testing without spending real ALGO.

#### Start LocalNet

```bash
# Start Algorand localnet with Docker
docker-compose up -d

# Wait for the network to initialize (~30 seconds)
sleep 30

# Check if it's running
curl http://localhost:4001/v2/status
```

#### Run Integration Tests on LocalNet

```bash
# Run integration tests against localnet
ALGORAND_NETWORK=localnet swift test

# Or run just integration tests
swift test --filter IntegrationTests
```

#### Manual Testing on LocalNet

```bash
# Run the interactive example
ALGORAND_NETWORK=localnet swift run algorand-example

# To send a transaction:
ALGORAND_NETWORK=localnet SEND_TRANSACTION=1 swift run algorand-example
```

#### Fund LocalNet Account

Your localnet comes with pre-funded accounts. To fund a new account:

```bash
# Get default account address (has funds)
docker exec algorand-sandbox-algod goal account list

# Fund your test account
docker exec algorand-sandbox-algod goal clerk send \
  -a 10000000000 \
  -f [DEFAULT_ACCOUNT_ADDRESS] \
  -t [YOUR_TEST_ACCOUNT_ADDRESS]
```

Or import an existing funded account:

```bash
# Export mnemonic from localnet
docker exec algorand-sandbox-algod goal account export -a [ADDRESS]

# Use it in tests
export ALGORAND_MNEMONIC="your 25 word mnemonic here"
ALGORAND_NETWORK=localnet swift run algorand-example
```

#### Stop LocalNet

```bash
docker-compose down

# To completely reset (deletes blockchain data)
docker-compose down -v
```

### TestNet (Public Test Network)

TestNet is Algorand's public test network. Tokens have no real value.

#### Run Integration Tests on TestNet

```bash
# Run integration tests
ALGORAND_NETWORK=testnet swift test --filter IntegrationTests

# Skip transaction tests (requires funded account)
SKIP_INTEGRATION_TESTS=1 swift test
```

#### Manual Testing on TestNet

```bash
# Create a new account and get the address
ALGORAND_NETWORK=testnet swift run algorand-example

# The program will output your address. Fund it at:
# https://bank.testnet.algorand.network/

# Once funded, save your mnemonic and run:
export ALGORAND_MNEMONIC="your 25 word mnemonic"
ALGORAND_NETWORK=testnet SEND_TRANSACTION=1 swift run algorand-example
```

#### Get TestNet Funds

1. Run the example to create an account
2. Copy your address
3. Visit https://bank.testnet.algorand.network/
4. Paste your address and click "Dispense"
5. Wait ~5 seconds for funds to arrive

### MainNet (Production - Use with Caution!)

MainNet is the production Algorand blockchain. **Tokens have real value!**

#### Query MainNet (Read-Only)

```bash
# Safe: only queries data, doesn't send transactions
ALGORAND_NETWORK=mainnet swift test --filter IntegrationTests.testGetStatus
ALGORAND_NETWORK=mainnet swift test --filter IntegrationTests.testIndexerHealth
```

#### ⚠️ Send Transactions on MainNet

**Only do this if you know what you're doing!**

```bash
export ALGORAND_MNEMONIC="your real mainnet account mnemonic"
ALGORAND_NETWORK=mainnet SEND_TRANSACTION=1 swift run algorand-example
```

## Environment Variables

### Network Configuration

- `ALGORAND_NETWORK` - Network to use: `localnet`, `testnet`, or `mainnet` (default: `testnet`)
- `ALGORAND_MNEMONIC` - 25-word mnemonic phrase to import an existing account
- `SEND_TRANSACTION` - Set to `1` to enable transaction sending in examples
- `SKIP_INTEGRATION_TESTS` - Set to `1` to skip integration tests

### LocalNet Custom Configuration

If you're running localnet on different ports:

```bash
# Modify docker-compose.yml ports, then:
# Update the localnet config in Sources/AlgorandExample/main.swift
# and Tests/AlgorandTests/IntegrationTests.swift
```

## Example Workflows

### Development Workflow

```bash
# 1. Start localnet
docker-compose up -d

# 2. Run unit tests
swift test

# 3. Run integration tests
ALGORAND_NETWORK=localnet swift test --filter IntegrationTests

# 4. Manual testing
ALGORAND_NETWORK=localnet swift run algorand-example

# 5. Stop localnet when done
docker-compose down
```

### Testing Against TestNet

```bash
# 1. Create account
ALGORAND_NETWORK=testnet swift run algorand-example

# 2. Fund it at https://bank.testnet.algorand.network/

# 3. Save mnemonic
export ALGORAND_MNEMONIC="your mnemonic from step 1"

# 4. Run tests
ALGORAND_NETWORK=testnet swift run algorand-example
ALGORAND_NETWORK=testnet SEND_TRANSACTION=1 swift run algorand-example

# 5. Run integration tests
ALGORAND_NETWORK=testnet swift test --filter IntegrationTests
```

### CI/CD Testing

```bash
# Unit tests only (no network)
swift test --filter '!IntegrationTests'

# With localnet in CI
docker-compose up -d
sleep 30
ALGORAND_NETWORK=localnet swift test
docker-compose down
```

## Troubleshooting

### LocalNet Not Starting

```bash
# Check if ports are already in use
lsof -i :4001
lsof -i :8980

# Check Docker logs
docker-compose logs algod
docker-compose logs indexer

# Reset everything
docker-compose down -v
docker-compose up -d
```

### "Account has no funds"

**LocalNet:**
```bash
# Use default funded account
docker exec algorand-sandbox-algod goal account list
docker exec algorand-sandbox-algod goal clerk send -a 10000000000 \
  -f [DEFAULT_ADDRESS] -t [YOUR_ADDRESS]
```

**TestNet:**
- Visit https://bank.testnet.algorand.network/
- Paste your address
- Click "Dispense"

### Integration Tests Failing

```bash
# Check network connectivity
curl http://localhost:4001/v2/status  # localnet
curl https://testnet-api.algonode.cloud/v2/status  # testnet

# Run with verbose output
swift test --filter IntegrationTests --verbose
```

### Docker Issues on macOS

```bash
# Ensure Docker Desktop is running
open -a Docker

# Restart Docker daemon
docker-compose down
docker system prune -f
docker-compose up -d
```

## Test Coverage

### Unit Tests (17 tests)
- ✅ Address encoding/decoding
- ✅ MicroAlgos arithmetic
- ✅ Account creation/signing
- ✅ Mnemonic generation/validation

### Integration Tests (7 tests)
- ✅ Network status
- ✅ Transaction parameters
- ✅ Account information
- ✅ Indexer health
- ✅ Search accounts/transactions
- ✅ Send payment transaction (requires funds)

## Network Comparison

| Feature | LocalNet | TestNet | MainNet |
|---------|----------|---------|---------|
| Setup | Docker | None | None |
| Speed | Fast (instant) | ~4 sec/block | ~4 sec/block |
| Funds | Unlimited (free) | Free (faucet) | Real money! |
| Reset | Easy (docker down -v) | Can't reset | Can't reset |
| Use Case | Development | Testing | Production |
| Block Explorer | None | AlgoExplorer | AlgoExplorer |

## Best Practices

1. **Always start with unit tests** - No network required
2. **Use localnet for development** - Fast, free, resettable
3. **Use testnet before mainnet** - Catch issues without cost
4. **Never commit mnemonics** - Use environment variables
5. **Test transactions on localnet first** - Verify logic before spending real tokens
6. **Keep localnet running during development** - Faster iteration

## Additional Resources

- [Algorand Developer Portal](https://developer.algorand.org)
- [Run a Node](https://developer.algorand.org/docs/run-a-node/setup/install/)
- [TestNet Dispenser](https://bank.testnet.algorand.network/)
- [AlgoExplorer TestNet](https://testnet.algoexplorer.io/)
