# ``Algorand``

Modern Swift SDK for the Algorand blockchain.

## Overview

swift-algorand provides a type-safe, async/await Swift interface for interacting with the Algorand blockchain. It supports account management, transaction creation and signing, atomic transaction groups, and querying both Algod and Indexer APIs.

All types are `Sendable` for safe use with Swift concurrency, and network clients use the `actor` model for thread-safe API access.

## Topics

### Essentials

- <doc:GettingStarted>

### Network Clients

- ``AlgodClient``
- ``IndexerClient``
- ``AlgorandConfiguration``

### Accounts and Keys

- ``Account``
- ``Address``
- ``Mnemonic``

### Transactions

- ``Transaction``
- ``PaymentTransaction``
- ``PaymentTransactionBuilder``
- ``SignedTransaction``

### Asset Transactions

- ``AssetCreateTransaction``
- ``AssetTransferTransaction``
- ``AssetOptInTransaction``
- ``AssetConfigTransaction``
- ``AssetFreezeTransaction``
- ``AssetClawbackTransaction``
- ``AssetParams``

### Application Transactions

- ``ApplicationCallTransaction``
- ``OnCompletion``
- ``StateSchema``

### Atomic Groups

- ``AtomicTransactionGroup``
- ``SignedAtomicTransactionGroup``
- ``AtomicTransactionGroupBuilder``

### Common Types

- ``MicroAlgos``
- ``TransactionParams``

### Errors

- ``AlgorandError``
- ``AmountError``
- ``FeeError``
- ``TransactionAuthorizationError``
