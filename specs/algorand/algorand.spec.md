---
module: algorand
version: 2
status: active
files:
  - Package.swift
  - Sources/Algorand/Account.swift
  - Sources/Algorand/Address.swift
  - Sources/Algorand/AlgodClient.swift
  - Sources/Algorand/AlgorandConfiguration.swift
  - Sources/Algorand/AlgorandError.swift
  - Sources/Algorand/ApplicationTransaction.swift
  - Sources/Algorand/AssetTransaction.swift
  - Sources/Algorand/AtomicTransactionGroup.swift
  - Sources/Algorand/BIP39Wordlist.swift
  - Sources/Algorand/IndexerClient.swift
  - Sources/Algorand/KeyRegistrationTransaction.swift
  - Sources/Algorand/MessagePackWriter.swift
  - Sources/Algorand/MicroAlgos.swift
  - Sources/Algorand/Mnemonic.swift
  - Sources/Algorand/PaymentTransaction.swift
  - Sources/Algorand/SecureRandom.swift
  - Sources/Algorand/SHA512_256.swift
  - Sources/Algorand/SignedTransaction.swift
  - Sources/Algorand/Transaction.swift

db_tables: []
depends_on: []
---

# Swift Algorand SDK

## Purpose

Provide the existing Swift SDK primitives for Algorand accounts, addresses, amounts, mnemonics, transactions, signing, atomic groups, and asynchronous Algod and Indexer clients across the package's supported Apple and Linux platforms.

## Public API

### Contract groups

| Existing surface | Contract |
|---|---|
| Accounts, addresses, mnemonics, hashes, and amounts | Validate protocol representations, create or restore keys, sign and verify bytes, and preserve Algorand encodings. |
| Transactions and MessagePack | Build and encode payment, asset, application, and key-registration transactions with explicit invalid-input failures. |
| Atomic groups and signed transactions | Preserve transaction order, derive one group identifier, sign with the matching accounts, and encode submission payloads. |
| `AlgodClient` | Asynchronously read node state, submit transactions, wait for confirmations, inspect applications/assets/boxes, and simulate transaction groups. |
| `IndexerClient` | Asynchronously query indexed accounts, transactions, assets, applications, blocks, pagination, and health. |
| Response models | Decode the currently exposed node/indexer JSON fields into `Codable & Sendable` values without concealing absent optional data. |
| Configuration and errors | Select localnet, TestNet, MainNet, or custom endpoints and surface validation, transport, API, encoding, and decoding failures. |

### Complete Swift export inventory

SpecSync 5.0.1 extracts the following 344 unique public symbols from the 19 canonical Swift source files. Repeated property names appear once because coverage is symbol-name based.

| Symbol |
|---|
| `Account` |
| `address` |
| `publicKey` |
| `mnemonic` |
| `sign` |
| `verify` |
| `description` |
| `init` |
| `Address` |
| `bytes` |
| `==` |
| `hash` |
| `encode` |
| `AlgodClient` |
| `status` |
| `waitForBlock` |
| `transactionParams` |
| `sendTransaction` |
| `sendTransactionGroup` |
| `pendingTransaction` |
| `waitForConfirmation` |
| `accountInformation` |
| `applicationInfo` |
| `accountApplicationInfo` |
| `applicationBoxes` |
| `applicationBox` |
| `simulateTransaction` |
| `assetInfo` |
| `NodeStatus` |
| `lastRound` |
| `lastVersion` |
| `nextVersion` |
| `nextVersionRound` |
| `nextVersionSupported` |
| `timeSinceLastRound` |
| `catchupTime` |
| `PendingTransaction` |
| `confirmedRound` |
| `poolError` |
| `txn` |
| `assetIndex` |
| `applicationIndex` |
| `TransactionData` |
| `AccountInformation` |
| `amount` |
| `amountWithoutPendingRewards` |
| `pendingRewards` |
| `round` |
| `assets` |
| `createdAssets` |
| `appsLocalState` |
| `createdApps` |
| `authAddr` |
| `minBalance` |
| `totalAppsOptedIn` |
| `totalAssetsOptedIn` |
| `totalCreatedApps` |
| `totalCreatedAssets` |
| `CreatedAsset` |
| `index` |
| `params` |
| `AssetParamsResponse` |
| `creator` |
| `decimals` |
| `total` |
| `defaultFrozen` |
| `unitName` |
| `name` |
| `url` |
| `metadataHash` |
| `manager` |
| `reserve` |
| `freeze` |
| `clawback` |
| `ApplicationLocalState` |
| `id` |
| `keyValue` |
| `schema` |
| `CreatedApplication` |
| `ApplicationParamsResponse` |
| `approvalProgram` |
| `clearStateProgram` |
| `globalState` |
| `globalStateSchema` |
| `localStateSchema` |
| `extraProgramPages` |
| `StateSchemaResponse` |
| `numByteSlice` |
| `numUint` |
| `TealKeyValue` |
| `key` |
| `value` |
| `TealValue` |
| `type` |
| `uint` |
| `ApplicationInfo` |
| `AccountApplicationInfo` |
| `appLocalState` |
| `createdApp` |
| `BoxesResponse` |
| `boxes` |
| `BoxDescriptor` |
| `BoxResponse` |
| `SimulateRequest` |
| `txnGroups` |
| `allowEmptySignatures` |
| `allowMoreLogging` |
| `allowUnnamedResources` |
| `execTraceConfig` |
| `extraOpcodeBudget` |
| `SimulateRequestTransactionGroup` |
| `txns` |
| `ExecTraceConfig` |
| `enable` |
| `scratchChange` |
| `stackChange` |
| `stateChange` |
| `SimulateResponse` |
| `version` |
| `evalOverrides` |
| `initialStates` |
| `SimulateTransactionGroupResult` |
| `txnResults` |
| `failedAt` |
| `failureMessage` |
| `appBudgetAdded` |
| `appBudgetConsumed` |
| `unnamedResourcesAccessed` |
| `SimulateTransactionResult` |
| `txnResult` |
| `logicSigBudgetConsumed` |
| `execTrace` |
| `EvalOverrides` |
| `maxLogCalls` |
| `maxLogSize` |
| `InitialStates` |
| `appInitialStates` |
| `ApplicationInitialStates` |
| `appBoxes` |
| `appGlobals` |
| `appLocals` |
| `ApplicationKVDelta` |
| `account` |
| `kvs` |
| `AvmKeyValue` |
| `AvmValue` |
| `UnnamedResourcesAccessed` |
| `accounts` |
| `apps` |
| `assetHoldings` |
| `extraBoxRefs` |
| `ApplicationLocalReference` |
| `app` |
| `AssetHoldingReference` |
| `asset` |
| `BoxReference` |
| `SimulationTransactionExecTrace` |
| `approvalProgramHash` |
| `approvalProgramTrace` |
| `clearStateProgramHash` |
| `clearStateProgramTrace` |
| `clearStateRollback` |
| `clearStateRollbackError` |
| `innerTrace` |
| `logicSigHash` |
| `logicSigTrace` |
| `SimulationOpcodeTraceUnit` |
| `pc` |
| `scratchChanges` |
| `spawnedInners` |
| `stackAdditions` |
| `stackPopCount` |
| `stateChanges` |
| `ScratchChange` |
| `newValue` |
| `slot` |
| `ApplicationStateOperation` |
| `appStateType` |
| `operation` |
| `AssetInfo` |
| `AssetHolding` |
| `assetID` |
| `isFrozen` |
| `AlgorandConfiguration` |
| `Network` |
| `network` |
| `apiToken` |
| `localnet` |
| `testnet` |
| `mainnet` |
| `custom` |
| `algodURL` |
| `indexerURL` |
| `AlgorandError` |
| `errorDescription` |
| `invalidAddress` |
| `invalidMnemonic` |
| `invalidTransaction` |
| `networkError` |
| `encodingError` |
| `decodingError` |
| `invalidResponse` |
| `apiError` |
| `OnCompletion` |
| `StateSchema` |
| `ApplicationCallTransaction` |
| `sender` |
| `applicationID` |
| `onCompletion` |
| `appArguments` |
| `foreignApps` |
| `foreignAssets` |
| `extraPages` |
| `fee` |
| `firstValid` |
| `lastValid` |
| `genesisID` |
| `genesisHash` |
| `note` |
| `lease` |
| `rekeyTo` |
| `create` |
| `update` |
| `delete` |
| `optIn` |
| `closeOut` |
| `clearState` |
| `call` |
| `noOp` |
| `updateApplication` |
| `deleteApplication` |
| `AssetParams` |
| `assetName` |
| `toBaseUnits` |
| `toDecimal` |
| `AssetCreateTransaction` |
| `assetParams` |
| `AssetOptInTransaction` |
| `AssetFreezeTransaction` |
| `freezeAccount` |
| `frozen` |
| `AssetConfigTransaction` |
| `strictEmptyAddressChecking` |
| `destroy` |
| `AssetTransferTransaction` |
| `receiver` |
| `closeRemainderTo` |
| `AssetClawbackTransaction` |
| `assetSender` |
| `assetReceiver` |
| `AtomicTransactionGroup` |
| `transactions` |
| `groupID` |
| `maxGroupSize` |
| `SignedAtomicTransactionGroup` |
| `signedTransactions` |
| `AtomicTransactionGroupBuilder` |
| `add` |
| `build` |
| `IndexerClient` |
| `health` |
| `searchAccounts` |
| `searchTransactions` |
| `transaction` |
| `searchAssets` |
| `application` |
| `searchApplications` |
| `block` |
| `HealthStatus` |
| `isMigrating` |
| `dbAvailable` |
| `AccountsResponse` |
| `currentRound` |
| `nextToken` |
| `AccountResponse` |
| `IndexerAccount` |
| `TransactionsResponse` |
| `TransactionResponse` |
| `IndexerTransaction` |
| `roundTime` |
| `txType` |
| `paymentTransaction` |
| `assetTransferTransaction` |
| `assetConfigTransaction` |
| `noteData` |
| `noteString` |
| `PaymentTransactionDetails` |
| `closeAmount` |
| `AssetTransferTransactionDetails` |
| `AssetConfigTransactionDetails` |
| `AssetConfigParams` |
| `AssetsResponse` |
| `AssetResponse` |
| `IndexerAsset` |
| `BlockResponse` |
| `ApplicationResponse` |
| `ApplicationsResponse` |
| `applications` |
| `IndexerApplication` |
| `createdAtRound` |
| `deletedAtRound` |
| `deleted` |
| `ApplicationParams` |
| `StateSchemaInfo` |
| `KeyRegistrationTransaction` |
| `votePK` |
| `selectionPK` |
| `voteFirst` |
| `voteLast` |
| `voteKeyDilution` |
| `nonparticipation` |
| `stateProofPK` |
| `online` |
| `offline` |
| `nonparticipating` |
| `MessagePackWriter` |
| `write` |
| `MessagePackValue` |
| `string` |
| `binary` |
| `map` |
| `array` |
| `bool` |
| `MicroAlgos` |
| `algos` |
| `+` |
| `-` |
| `*` |
| `/` |
| `Mnemonic` |
| `generate` |
| `decode` |
| `isValid` |
| `PaymentTransaction` |
| `PaymentTransactionBuilder` |
| `validRounds` |
| `SHA512_256` |
| `SignedTransaction` |
| `signature` |
| `TransactionParams` |
| `consensusVersion` |
| `minFee` |
| `firstRound` |
| `Transaction` |

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
| 2 | 2026-07-14 | Adopt SpecSync 5.0.1 and Trust 1.0.0 governance with complete source, export, and requirement coverage. |

## Complete API and source inventory

The active spec maps all 19 canonical Swift source files and documents all 344 unique public symbols extracted by SpecSync 5.0.1. The inventory is organized by accounts and cryptography, protocol encoding, transaction families, atomic grouping, Algod, Indexer, response models, configuration, and errors.
