# algorand

## MODIFIED

### SPEC SECTION Purpose
Provide the existing Swift SDK primitives for Algorand accounts, addresses, amounts, mnemonics, transactions priced under the consensus v42 usage-based fee model, signing (Ed25519 and, since consensus v42, native post-quantum Falcon-1024 through a caller-supplied signer), atomic groups with a pooled fee requirement, and asynchronous Algod and Indexer clients across the package's supported Apple and Linux platforms.

### SPEC SECTION Public API
### Contract groups

| Existing surface | Contract |
|---|---|
| Accounts, addresses, mnemonics, hashes, and amounts | Validate protocol representations, create or restore keys, sign and verify bytes, and preserve Algorand encodings. |
| Transactions and MessagePack | Build and encode payment, asset, application, and key-registration transactions in go-algorand's canonical omit-empty MessagePack form, price their fees with a `FeeStrategy` against suggested parameters under the consensus v42 usage model, with explicit invalid-input failures. |
| Atomic groups and signed transactions | Preserve transaction order, derive one group identifier, report the group's pooled consensus v42 fee usage and requirement, sign with the matching accounts or any `TransactionSigner`, carry `sgnr` for a rekeyed sender, carry a Falcon-1024 `pqsig` for a native post-quantum account, and encode submission payloads as go-algorand's omit-empty `SignedTxn` map. |
| `AlgodClient` | Asynchronously read node state, submit transactions, wait for confirmations, inspect applications/assets/boxes, and simulate transaction groups. |
| `IndexerClient` | Asynchronously query indexed accounts, transactions, assets, applications, blocks, pagination, and health. |
| Response models | Decode the currently exposed node/indexer JSON fields into `Codable & Sendable` values without concealing absent optional data. |
| Configuration and errors | Select localnet, TestNet, MainNet, or custom endpoints and surface validation, transport, API, encoding, and decoding failures. |

### Complete Swift export inventory

SpecSync 6.0.0 extracts the following 378 unique public symbols from the 33 canonical Swift source files. Repeated property names appear once because coverage is symbol-name based. The 17 names added by the post-quantum envelope change and the 17 names added by the consensus v42 fee-model change are listed at the end of the table, in that order.

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
| `PQScheme` |
| `falcon1024` |
| `PQSignature` |
| `scheme` |
| `salt` |
| `TransactionAuthorization` |
| `ed25519` |
| `postQuantum` |
| `TransactionAuthorizationError` |
| `authAddrMismatch` |
| `unauthorizedProof` |
| `malformed` |
| `TransactionSigner` |
| `authorize` |
| `PQSigner` |
| `bytesToSign` |
| `authorization` |
| `FeeStrategy` |
| `minimum` |
| `flat` |
| `suggested` |
| `TransactionUsage` |
| `micros` |
| `adding` |
| `feeUsage` |
| `AlgorandConsensus` |
| `v42` |
| `identifier` |
| `minimumFee` |
| `requiredFee` |
| `checkFees` |
| `FeeError` |
| `overflow` |
| `insufficient` |

### SPEC SECTION Invariants
1. Address, mnemonic, key, signature, transaction, and MessagePack representations must preserve the existing Algorand protocol encodings and validation behavior, where the transaction encoding is go-algorand v5.0.1-stable's canonical omit-empty form.
2. Transaction builders must reject incomplete or invalid inputs rather than construct an apparently valid transaction.
3. Network clients use asynchronous APIs and surface transport, decoding, and protocol failures as errors.
4. Atomic transaction groups preserve ordering and assign one deterministic group identifier to the grouped transactions.
5. Credentialed TestNet sends and live network checks remain explicitly authorized and outside the blocking pull-request lane.
6. Every transaction field passes through one internal omit-empty choke point, and every transaction type installs its shared header through one call. A field is written only when it differs from its go-algorand zero value. Boolean fields are encoded as MessagePack booleans and omitted when false. Box references carry an `apfa` slot index — `0` for the called application, otherwise the 1-based position — never a raw application identifier, and an undeclared application is appended to `apfa` up to the eight-application limit.
7. The bytes signed and the bytes submitted are produced by the same encoding call, and a transaction identifier is always the hash of the bytes that were signed. For a transaction signed as part of an atomic group that means the encoding including `grp`.
8. A signed-transaction envelope is go-algorand's omit-empty `SignedTxn` map: keys in canonical order `lsig < msig < pqsig < sgnr < sig < txn`, only present keys written, every binary header chosen by length through the canonical MessagePack writer, and the bytes under `txn` are the bytes that were signed. An envelope carrying only an Ed25519 signature is byte-identical to the fixed `0x82 {sig, txn}` encoding of every previous release.
9. `sgnr` is present exactly when the signer's address differs from the sender. A post-quantum proof is attached only after its scheme, salt, and public key are shown to derive the authorizer, and the signing preimage `"TX" || msgpack(txn)` is handed to signers unhashed. No Falcon implementation is bundled; signatures come from a caller-supplied `TransactionSigner`.
10. Fees follow consensus v42's usage model. Every transaction owes `1_000_000` micro-units of usage plus `100` per note byte beyond 1024; an application call adds `100` per application-argument byte beyond 2048 and per approval-plus-clear-state program byte beyond 8192; a Falcon-1024 envelope adds `2_000_000`; `apep`, boxes, accounts, foreign references, schemas, and Ed25519 signatures add nothing. A group's requirement is `ceil(sum(usage) * minFee / 1_000_000)` over the pooled usage of its members, compared with the sum of their fees, with no per-transaction check. A `FeeStrategy` is resolved for one transaction against suggested parameters, `.minimum` by default; the header-field initializers default to `AlgorandConsensus.v42.minimumFee`. Fee arithmetic throws `FeeError.overflow` and never saturates, and a transaction whose fee is given explicitly encodes byte-identically to every previous release.

### SPEC SECTION Behavioral Examples
```
Given a valid account and complete payment parameters
When a payment transaction is built, signed, and encoded
Then the result preserves the documented Algorand fields and can be submitted by an authorized caller
```

```
Given a payment whose fee, note, and lease are zero or empty
When the transaction is encoded and signed
Then those fields are absent from the encoding, and a consensus v42 node accepts the signature
```

```
Given a transaction whose sender has been rekeyed to another account
When the rekeyed-to account signs it
Then the envelope carries that account's address as sgnr, and omits sgnr when the sender signs for itself
```

```
Given a 1793-byte Falcon-1024 public key and a callback that signs bytes with its private key
When a PQSigner is created and signs a transaction whose sender is the derived post-quantum address
Then the envelope is {pqsig: {pk, sch: "f1", sig[, slt]}, txn}, the callback received "TX" || msgpack(txn) unhashed, and a consensus v42 node proceeds to Falcon signature verification
```

```
Given suggested parameters whose min-fee is 2000 and a payment with no priced bytes
When the payment is built with the default FeeStrategy.minimum
Then it carries fee 2000, and its bytes and identifier equal the pay_min_fee_from_params golden vector
```

```
Given two payments built with .flat(0) and grouped
When the group's requiredFee(minFee:) is placed on the first member and the group is rebuilt and signed
Then checkFees(minFee:) passes, a consensus v42 node reports group-usage 2000000 and group-fees-paid equal to that fee, and one microAlgo less throws FeeError.insufficient locally
```

### SPEC SECTION Error Cases
| Error | When | Behavior |
|-------|------|----------|
| Invalid address or mnemonic | Input fails protocol validation | Return a typed error without creating an account value |
| Incomplete transaction | A required builder field is absent | Return an error instead of producing a transaction |
| Invalid signature or group | Cryptographic or grouping validation fails | Reject the operation |
| Network failure | A node or indexer request fails or returns invalid data | Surface an asynchronous error |
| Encoding failure | A transaction map exceeds MessagePack's map or array limits | Throw `AlgorandError.encodingError` rather than emit a truncated encoding |
| Too many foreign applications | Box references would extend `apfa` past eight entries | Throw `AlgorandError.invalidTransaction` at encode time rather than let the node reject it |

| Auth address mismatch | An explicit `authAddr` names an address other than the signer's | Throw `TransactionAuthorizationError.authAddrMismatch` before signing |
| Unauthorized post-quantum proof | A `pqsig` proof's scheme, salt, and public key derive an address other than the authorizer | Throw `TransactionAuthorizationError.unauthorizedProof` at sign time and again at encode time |
| Malformed authorization | A post-quantum public key, signature, or scheme tag has a size the network's decoder rejects | Throw `TransactionAuthorizationError.malformed` before an envelope is built |
| Fee overflow | A usage sum, a fee product, or a paid-fee total exceeds 64 bits | Throw `FeeError.overflow` rather than saturate to `UInt64.max` |
| Insufficient group fee | A signed group's fees sum to less than its pooled consensus v42 requirement | Throw `FeeError.insufficient(required:paid:)` from `checkFees(minFee:)` before submission |

No new `AlgorandError` case is introduced. `TransactionAuthorizationError` is the one error type added by the post-quantum envelope change and `FeeError` the one added by the fee-model change; Ed25519 signature bytes are carried verbatim and never validated locally. A box reference naming an application absent from `apfa` appends that application rather than failing, up to the limit above.

### SPEC SECTION Complete API and source inventory
The active spec maps all 33 canonical Swift source files and documents all 378 unique public symbols extracted by SpecSync 6.0.0. The inventory is organized by accounts and cryptography, canonical protocol encoding, signed-transaction envelopes and post-quantum authorization, the consensus v42 fee model, transaction families, atomic grouping, Algod, Indexer, response models, configuration, and errors. The two files added for canonical encoding, `CanonicalTransactionFields.swift` and `CanonicalBoxReferences.swift`, and the `Edwards25519.swift` point predicate added for post-quantum address derivation are internal and contribute no public symbol. The other six files added by the post-quantum envelope change (`Address+PostQuantum.swift`, `PQScheme.swift`, `PQSignature.swift`, `Transaction+Signing.swift`, `TransactionAuthorization.swift`, `TransactionSigner.swift`) contribute the 17 names listed at the end of the export inventory. The five files added by the consensus v42 fee-model change (`AlgorandConsensus.swift`, `AtomicTransactionGroup+Fees.swift`, `FeeError.swift`, `FeeStrategy.swift`, `TransactionUsage.swift`) contribute the 17 names listed last in the export inventory.

## ADDED

### REQUIREMENT REQ-algorand-024
Every transaction builder, params-based initializer, and params-based factory SHALL accept a `FeeStrategy` — `.minimum` (the default), `.flat(MicroAlgos)`, or `.suggested` — and SHALL resolve it against `TransactionParams` for the transaction alone: `.minimum` is `ceil(usage * min-fee / 1_000_000)`, `.flat` is carried verbatim including zero, and `.suggested` is `max(minimum, fee * (encoded size + 75))` when the per-byte `fee` is non-zero and the minimum otherwise. `TransactionParams` SHALL decode the per-byte `fee`, defaulting to 0 when absent, and SHALL offer a public memberwise initializer. The header-field initializers and factories SHALL keep their signatures and SHALL default `fee` to `AlgorandConsensus.v42.minimumFee`.

Acceptance Criteria
- `testMinimumStrategyReadsMinFeeFromParams` reproduces the `pay_min_fee_from_params` golden bytes and transaction ID through both `PaymentTransactionBuilder` and `PaymentTransaction.init(sender:receiver:amount:fee:params:validRounds:note:lease:rekeyTo:closeRemainderTo:)`.
- `testMinimumStrategyPricesUsage`, `testFlatStrategyIsCarriedVerbatim`, `testSuggestedStrategyFloorsAtMinimum`, `testStrategyResolvesForAnyTransaction`, `testBuilderFeeOverloads`, `testParamsInitializersAndFactoriesAcrossTypes` (all eight params-based initializers and all eleven params-based factories), `testHeaderFieldInitializersDefaultToTheCertifiedMinimum`, `testTransactionParamsDecodesFeePerByte`, and `testValidRoundsOverflowIsAnError` pass.
- Every pre-existing XCTest compiles and passes unchanged: 98 executed, 20 skipped, 0 failures.

*Rationale: 21 initializer and factory defaults and the builder's stored `fee` hardcoded `MicroAlgos(1000)` while `TransactionParams.minFee` was decoded and never read; the header-field forms cannot read parameters they are not given, so they keep a named protocol constant instead of a magic number.*

### REQUIREMENT REQ-algorand-025
`Transaction.feeUsage()` SHALL return the consensus v42 usage in micro-units: `1_000_000` plus `100` per note byte beyond 1024. `ApplicationCallTransaction.feeUsage()` SHALL add `100` per application-argument byte beyond 2048, summed over every argument, and `100` per approval-plus-clear-state program byte beyond 8192; `extraPages`, boxes, accounts, foreign references, and schemas SHALL contribute nothing. `PQScheme.feeUsage` SHALL be `2_000_000` for Falcon-1024 and 0 for any other scheme, `TransactionAuthorization.feeUsage` SHALL be 0 for Ed25519, and `SignedTransaction.feeUsage()` SHALL be the sum of the transaction's and the authorization's usage. `TransactionUsage.fee(minFee:)` SHALL be `ceil(micros * minFee / 1_000_000)` computed at full 128-bit width.

Acceptance Criteria
- `testHeaderUsageIsOneFeePlusNoteSurcharge` reports 1000000, 1000000, 1000100, 1097600, and 1307200 micro-units for notes of 0, 1024, 1025, 2000, and 4096 bytes, and fees of 1000, 1000, 1001, 1098, 1308 at `minFee` 1000 and 2000, 2000, 2001, 2196, 2615 at `minFee` 2000.
- `testNonApplicationTypesUseHeaderUsageOnly`, `testApplicationUsagePricesArgumentsAndPrograms`, `testSignatureUsage`, and `testFeeRoundsUpOnce` pass.
- Live: a TestNet v42 node's `group-usage` equals the SDK's usage for a 2000-byte-note payment (1097600), an application create with 4000 argument bytes (1195200), and one with 12000 program bytes over five extra pages (1380800).

### REQUIREMENT REQ-algorand-026
`AtomicTransactionGroup.feeUsage()` SHALL sum the members' usage as Ed25519-signed transactions, `SignedAtomicTransactionGroup.feeUsage()` SHALL sum the envelopes' usage including post-quantum contributions, `requiredFee(minFee:)` on both SHALL be a single rounding over the pooled usage, and `SignedAtomicTransactionGroup.checkFees(minFee:)` SHALL return the requirement or throw `FeeError.insufficient(required:paid:)` when the members' fees sum to less. No per-transaction fee check SHALL be made: a member may carry a zero fee when another member covers it.

Acceptance Criteria
- `testGroupUsageIsPooled` shows two members whose own requirements are 1001 each pooling to 2001, not 2002.
- `testSignedGroupCheckFees` accepts a group paying 2000 on the first member and 0 on the second, and reports `insufficient(required: 2000, paid: 1999)` when one microAlgo short.
- `testSignedGroupCountsPostQuantumEnvelopes` raises a two-member requirement from 2000 to 4000 for one Falcon-1024 envelope, equal to `group.feeUsage().adding(PQScheme.falcon1024.feeUsage)`.
- Live: the pooled two-payment group simulates on TestNet v42 with `group-usage` 2000000 and `group-fees-paid` 2000, and the mixed payment-plus-application group with `group-usage` 2292800, both reaching `overspend` past signature verification.

### REQUIREMENT REQ-algorand-027
Fee arithmetic SHALL never saturate: `TransactionUsage.adding(_:)`, `TransactionUsage.fee(minFee:)`, `FeeStrategy.suggested`, and the paid-fee total in `checkFees(minFee:)` SHALL throw `FeeError.overflow` when a value exceeds 64 bits, and a validity window past `UInt64.max` SHALL throw `AlgorandError.invalidTransaction`. `FeeError` SHALL be the only error type added; no `AlgorandError` case is added and `MicroAlgos` arithmetic is untouched.

Acceptance Criteria
- `testOverflowThrowsInsteadOfSaturating` covers the usage product, the usage sum, the suggested per-byte product, and the paid-fee total, and shows `UInt64.max` usage at `minFee` 1000000 resolving to `MicroAlgos(UInt64.max)` exactly rather than overflowing.
- `testValidRoundsOverflowIsAnError` and `testFeeErrorsDescribeThemselves` pass.
- `Sources/Algorand/MicroAlgos.swift` and `Sources/Algorand/AlgorandError.swift` are unchanged from the base tree.

### REQUIREMENT REQ-algorand-028
`AlgorandConsensus.v42` SHALL name the certified protocol by its exact `consensus-version` identifier, `https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f`, and its `MinTxnFee` of 1000 microAlgos. A transaction whose fee is given explicitly SHALL encode byte-identically to the base tree, and a params-based transaction SHALL encode byte-identically to the header-field form carrying the same fields.

Acceptance Criteria
- `testHeaderFieldInitializersDefaultToTheCertifiedMinimum` checks the identifier and the 1000 microAlgo minimum, and `testParamsInitializerMatchesHeaderFieldInitializer` matches a payment and an application call byte-for-byte across the two initializer forms.
- A harness built once against 4bea606 and once against this change prints identical output for 20 transactions bare and grouped, four signed envelopes standalone and grouped, and one group identifier (47 lines, `cmp` silent).
- Live: `GET /v2/transactions/params` on TestNet reports exactly that identifier as `consensus-version`.
