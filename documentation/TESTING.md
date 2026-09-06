# Testing Guide

This guide explains how the test suite is structured, how it is gated, and what each
invocation actually runs.

## The shape of the suite

There is one test target, `AlgorandTests`, containing 98 tests across 14 suites.

| Suite | Tests | Needs a network? |
|---|---|---|
| `AccountTests` | 4 | No |
| `AddressTests` | 4 | No |
| `ApplicationTransactionTests` | 10 | No |
| `AssetManagementTests` | 7 | No |
| `AssetTests` | 11 | No |
| `AtomicTransactionGroupTests` | 11 | No |
| `KeyRegistrationTests` | 4 | No |
| `MicroAlgosTests` | 5 | No |
| `MnemonicTests` | 6 | No |
| `PaymentTransactionTests` | 2 | No |
| `SHA512_256Tests` | 13 | No |
| `IntegrationTests` | 18 | Yes - LocalNet only |
| `ComprehensiveIntegrationTest` | 1 | Yes - LocalNet only |
| `ProofOfWorkTest` | 2 | 1 yes (LocalNet only), 1 no |

77 tests run with no network and no Docker. 21 live in the three network suites, one of
which (`ProofOfWorkTest.testMinimal`) needs no network either.

## Two environment variables, and only two

The test suite reads exactly two environment variables. The SDK itself reads none.

- **`ALGORAND_NETWORK`** - `localnet`, `testnet`, or `mainnet`. Defaults to `localnet`.
  It selects which endpoints the integration clients are built against. Every integration
  test is *additionally* gated on the value being `localnet`, so `testnet` and `mainnet`
  make the tests run and immediately skip.
- **`CI`** - if set to anything, `IntegrationTests` and `ComprehensiveIntegrationTest`
  skip in `setUp`. This is how the GitHub Actions lanes stay green without Docker.

There is no variable that supplies a mnemonic and none that enables sending. If you have
seen `ALGORAND_MNEMONIC`, `SEND_TRANSACTION`, or `SKIP_INTEGRATION_TESTS` referenced
anywhere, they are obsolete - no code has read them since the example target was removed.

## Quick Start

### Unit tests (no network, no Docker)

```bash
swift test --skip IntegrationTest --skip ProofOfWorkTest
```

Runs 77 tests, 0 failures. `--skip IntegrationTest` matches both `IntegrationTests` and
`ComprehensiveIntegrationTest`.

### The full suite the way CI runs it

```bash
CI=true swift test
```

Executes 98 tests with 20 skipped and 0 failures. The 20 are the 18 `IntegrationTests`, the
1 `ComprehensiveIntegrationTest`, and `ProofOfWorkTest.testProofOfAllTransactionTypes`.
`ProofOfWorkTest.testMinimal` has no network dependency and runs.

### Filter syntax

`swift test` takes regular expressions in `'<test-target>.<test-case>'` or
`'<test-target>.<test-case>/<test>'` form:

```bash
swift test --filter 'AlgorandTests.MnemonicTests'
swift test --filter 'AlgorandTests.IntegrationTests/testGetStatus'
```

There is **no negation syntax**. `--filter '!IntegrationTests'` is treated as an ordinary
regular expression, matches no test, and silently runs nothing. It will not
do what it looks like it does. To exclude, use `--skip`, which takes the same kind of
regular expression:

```bash
CI=true swift test --skip PaymentTransactionTests
```

## Network Testing

### LocalNet

LocalNet runs a private Algorand blockchain on your machine.

These commands use the Compose v2 spelling (`docker compose`). If you have the standalone
v1 binary instead, substitute `docker-compose` — `scripts/start-localnet.sh` detects which
of the two is available and uses it.

#### Start LocalNet

```bash
# Start algod, indexer and postgres with Docker
docker compose up -d

# Wait for the network to initialize (~30 seconds)
sleep 30

# Check that algod is answering
curl -H "X-Algo-API-Token: $(printf 'a%.0s' {1..64})" http://localhost:4001/v2/status

# Check that the indexer is answering
curl http://localhost:8980/health
```

`./scripts/start-localnet.sh` does all of the above and reports what it found.

#### Run integration tests against LocalNet

```bash
# The whole suite, integration tests included
ALGORAND_NETWORK=localnet swift test

# Only the integration suite
ALGORAND_NETWORK=localnet swift test --filter 'AlgorandTests.IntegrationTests'
```

`CI` must be unset for these to do anything. `ALGORAND_NETWORK` defaults to `localnet`, so
plain `swift test` on a developer machine already targets it.

#### What passes and what needs more setup

Six integration tests are read-only and pass against any local node listening on the
default ports: `testGetStatus`, `testGetTransactionParams`, `testGetAccountInformation`,
`testIndexerHealth`, `testSearchAccounts`, and `testSearchTransactions`.

The remaining twelve, plus `ComprehensiveIntegrationTest.testFullAlgorandWorkflow` and
`ProofOfWorkTest.testProofOfAllTransactionTypes`, submit real transactions and must fund
accounts first. Their funding helper shells out to Docker, and it does so with hardcoded
assumptions:

- the `docker` binary at `/opt/homebrew/bin/docker` (macOS, Homebrew)
- an algod container named **`algokit_sandbox_algod`** - the container that
  [AlgoKit LocalNet](https://github.com/algorandfoundation/algokit-cli) creates, **not**
  the `algorand-sandbox-algod` container this repository's `docker-compose.yml` creates
- a *default* kmd wallet inside that container holding a funded account

If any of those is missing the tests fail with `Error Domain=FundingError Code=1`, most
often `"Failed to list accounts: No default wallet found."`. That is an environment
mismatch, not an SDK defect. To set a default wallet in an AlgoKit LocalNet:

```bash
docker exec algokit_sandbox_algod goal wallet list -d /algod/data
docker exec algokit_sandbox_algod goal wallet -f unencrypted-default-wallet -d /algod/data
docker exec algokit_sandbox_algod goal account list -d /algod/data
```

Once `goal account list` prints an address with a balance, the funding helper can find it.

#### Fund an account by hand

Against this repository's `docker-compose.yml` stack the container is named
`algorand-sandbox-algod`:

```bash
# List accounts the node's wallet holds
docker exec algorand-sandbox-algod goal account list -d /algod/data

# Send from a funded account to your test account
docker exec algorand-sandbox-algod goal clerk send \
  -a 10000000000 \
  -f DEFAULT_ACCOUNT_ADDRESS \
  -t YOUR_TEST_ACCOUNT_ADDRESS \
  -d /algod/data
```

#### Stop LocalNet

```bash
docker compose down

# To completely reset (deletes blockchain data)
docker compose down -v
```

### TestNet and MainNet

**The test suite has no TestNet or MainNet coverage.** Every integration test skips unless
`ALGORAND_NETWORK=localnet`. Running

```bash
ALGORAND_NETWORK=testnet swift test --filter 'AlgorandTests.IntegrationTests'
```

reports `Executed 18 tests, with 18 tests skipped`. That is the intended behaviour: it is
not a way to test against TestNet, and no flag turns it into one.

To exercise TestNet, write a small program against the library. The
[Quick Start guide](QUICKSTART.md) contains a complete, runnable one that creates an
account, points you at the dispenser, and sends a self-payment once funded.

For MainNet, the same applies, with the obvious caveat that transactions there cost real
money. Read-only queries are safe; anything that calls `sendTransaction` is not. The SDK
gives you no guardrail beyond your own code, so gate mainnet signing behind an explicit
confirmation of your own.

Get TestNet funds at https://bank.testnet.algorand.network/ and inspect results at
https://lora.algokit.io/testnet.

## Troubleshooting

### Every integration test says "skipped"

Expected unless `ALGORAND_NETWORK=localnet` **and** `CI` is unset. Check both:

```bash
env | grep -E '^(CI|ALGORAND_NETWORK)='
```

### `--filter '!IntegrationTests'` runs nothing

There is no negation syntax. Use `--skip IntegrationTest` instead.

### LocalNet not starting

```bash
# Check if the ports are already in use
lsof -i :4001
lsof -i :8980

# Check Docker logs
docker compose logs algod
docker compose logs indexer

# Reset everything
docker compose down -v
docker compose up -d
```

Port 4001 already in use often means an AlgoKit LocalNet is running. Either use that one or
stop it before starting the compose stack.

### `FundingError` / "No default wallet found"

See "What passes and what needs more setup" above. The funding helper needs
`algokit_sandbox_algod` with a default wallet, reached through `/opt/homebrew/bin/docker`.

### Integration tests failing to connect

```bash
curl -H "X-Algo-API-Token: $(printf 'a%.0s' {1..64})" http://localhost:4001/v2/status                # localnet
curl https://testnet-api.algonode.cloud/v2/status   # testnet
```

### Docker issues on macOS

```bash
# Ensure Docker Desktop is running
open -a Docker

# Restart the stack
docker compose down
docker system prune -f
docker compose up -d
```

## Network Comparison

| Feature | LocalNet | TestNet | MainNet |
|---------|----------|---------|---------|
| Setup | Docker | None | None |
| Speed | Fast (instant) | ~3 sec/block | ~3 sec/block |
| Funds | Unlimited (free) | Free (dispenser) | Real money |
| Reset | Easy (`docker compose down -v`) | Cannot reset | Cannot reset |
| Covered by this test suite | Yes | No | No |
| Block explorer | Lora (localnet mode) | Lora | Allo |

## Best Practices

1. **Start with the unit tests** - 77 of the 98 tests need nothing but a compiler.
2. **Use LocalNet for anything that signs** - fast, free, resettable.
3. **Never commit mnemonics** - the SDK reads no environment variables, so key handling is
   entirely your program's responsibility.
4. **Treat TestNet as untested ground** - the suite does not cover it; your own program is
   the only thing exercising it.
5. **Keep LocalNet running during development** - faster iteration than restarting Docker.

## Additional Resources

- [Algorand Developer Portal](https://dev.algorand.co/)
- [Run a node](https://dev.algorand.co/nodes/overview/)
- [TestNet dispenser](https://bank.testnet.algorand.network/)
- [Lora block explorer](https://lora.algokit.io/testnet)
