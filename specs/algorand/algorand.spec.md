---
module: algorand
version: 1
status: active
files:
  - Package.swift

db_tables: []
depends_on: []
---

# Swift Algorand SDK

## Purpose

Provide the existing Swift SDK primitives for Algorand accounts, addresses, amounts, mnemonics, transactions, signing, atomic groups, and asynchronous Algod and Indexer clients across the package's supported Apple and Linux platforms.

## Public API

### Package Interface

The `Algorand` library product exposes the account, address, amount, mnemonic, hashing, transaction-builder, signing, atomic-group, node-client, indexer-client, asset, application, and key-registration APIs documented by the package and its DocC catalog.

## Invariants

1. Address, mnemonic, key, signature, transaction, and MessagePack representations must preserve the existing Algorand protocol encodings and validation behavior.
2. Transaction builders must reject incomplete or invalid inputs rather than construct an apparently valid transaction.
3. Network clients use asynchronous APIs and surface transport, decoding, and protocol failures as errors.
4. Atomic transaction groups preserve ordering and assign one deterministic group identifier to the grouped transactions.
5. Credentialed TestNet sends and live network checks remain explicitly authorized and outside the blocking pull-request lane.

## Behavioral Examples

```
Given a valid account and complete payment parameters
When a payment transaction is built, signed, and encoded
Then the result preserves the documented Algorand fields and can be submitted by an authorized caller
```

## Error Cases

| Error | When | Behavior |
|-------|------|----------|
| Invalid address or mnemonic | Input fails protocol validation | Return a typed error without creating an account value |
| Incomplete transaction | A required builder field is absent | Return an error instead of producing a transaction |
| Invalid signature or group | Cryptographic or grouping validation fails | Reject the operation |
| Network failure | A node or indexer request fails or returns invalid data | Surface an asynchronous error |

## Dependencies

- Swift 6.0 or newer
- `swift-crypto` for cross-platform cryptographic primitives
- Foundation networking and Swift concurrency
- Swift-DocC plugin for independent documentation publication

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1 | 2026-07-12 | Initial spec |
