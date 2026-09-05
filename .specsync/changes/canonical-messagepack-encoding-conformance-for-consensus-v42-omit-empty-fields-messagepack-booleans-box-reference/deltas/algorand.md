# algorand

## MODIFIED

### REQUIREMENT REQ-algorand-002
`MicroAlgos`, `SHA512_256`, secure randomness, and MessagePack encoding SHALL preserve protocol-compatible numeric, hash, random-byte, and canonical wire representations. Canonical means the encoding produced by go-algorand v5.0.1-stable's msgp-generated marshaller under `_struct codec:",omitempty,omitemptyarray"`, so that the bytes this package signs are the bytes a consensus v42 node reconstructs and verifies.

Acceptance Criteria
- Amount arithmetic and conversion, official hash vectors, and generated randomness use tests pass.
- The canonical golden-vector suite passes by byte equality of the encoded transaction and the base32 transaction identifier against vectors derived from go-algorand v5.0.1-stable.

*Rationale: the requirement text was already correct and the code already violated it. `fee`, `fv`, `gen`, `note`, and `lx` were emitted when zero or empty, and TestNet returned `HTTP 400 {"message":"At least one signature didn't pass verification"}`. The former acceptance criterion, "transaction encoding tests pass", was satisfiable by tests asserting `encoded.count > 0`.*

### REQUIREMENT REQ-algorand-007
Key-registration construction SHALL preserve online, offline, and nonparticipating vote, selection, dilution, state-proof, and participation fields, encoding `nonpart` as a MessagePack boolean and omitting it when false.

Acceptance Criteria
- Existing online, offline, nonparticipating, and signing tests pass.
- The `keyreg_nonparticipating` golden vector matches byte-for-byte, carrying `a76e6f6e70617274 c3`.
- The `keyreg_offline` golden vector omits `nonpart` entirely rather than encoding `false`.

*Rationale: `KeyRegistrationTransaction.encode` wrote `nonpart` as MessagePack `uint 1` (`0x01`). go-algorand writes it with `msgp.AppendBool` and reads it with `msgp.ReadBoolBytes`. A nonparticipating key registration built by this package could not be accepted by any node.*

### REQUIREMENT REQ-algorand-006
Application create, update, delete, opt-in, close-out, clear-state, and call transactions SHALL preserve programs, schemas, arguments, accounts, foreign references, boxes, completion mode, and extra-page fields, naming box references by owning application identifier and translating them to `apfa` slot indexes at encode time.

Acceptance Criteria
- Existing application transaction construction, encoding, foreign-reference, box, and signing tests pass.
- The `appl_*` golden vectors match byte-for-byte.

*Rationale: `boxes: [(UInt64, Data)]?` keeps its type and its documented `(app_id, box_name)` meaning. Only the encoder changes, to honour that meaning instead of writing the identifier into the wire index slot.*

### SPEC SECTION Public API
### Contract groups

| Existing surface | Contract |
|---|---|
| Accounts, addresses, mnemonics, hashes, and amounts | Validate protocol representations, create or restore keys, sign and verify bytes, and preserve Algorand encodings. |
| Transactions and MessagePack | Build and encode payment, asset, application, and key-registration transactions in go-algorand's canonical omit-empty MessagePack form, with explicit invalid-input failures. |
| Atomic groups and signed transactions | Preserve transaction order, derive one group identifier, sign with the matching accounts, and encode submission payloads. |
| `AlgodClient` | Asynchronously read node state, submit transactions, wait for confirmations, inspect applications/assets/boxes, and simulate transaction groups. |
| `IndexerClient` | Asynchronously query indexed accounts, transactions, assets, applications, blocks, pagination, and health. |
| Response models | Decode the currently exposed node/indexer JSON fields into `Codable & Sendable` values without concealing absent optional data. |
| Configuration and errors | Select localnet, TestNet, MainNet, or custom endpoints and surface validation, transport, API, encoding, and decoding failures. |

### Complete Swift export inventory

SpecSync 5.0.1 extracts the following 344 unique public symbols from the 21 canonical Swift source files. Repeated property names appear once because coverage is symbol-name based.

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

### SPEC SECTION Invariants
1. Address, mnemonic, key, signature, transaction, and MessagePack representations must preserve the existing Algorand protocol encodings and validation behavior, where the transaction encoding is go-algorand v5.0.1-stable's canonical omit-empty form.
2. Transaction builders must reject incomplete or invalid inputs rather than construct an apparently valid transaction.
3. Network clients use asynchronous APIs and surface transport, decoding, and protocol failures as errors.
4. Atomic transaction groups preserve ordering and assign one deterministic group identifier to the grouped transactions.
5. Credentialed TestNet sends and live network checks remain explicitly authorized and outside the blocking pull-request lane.
6. Every transaction field passes through one internal omit-empty choke point, and every transaction type installs its shared header through one call. A field is written only when it differs from its go-algorand zero value. Boolean fields are encoded as MessagePack booleans and omitted when false. Box references carry an `apfa` slot index — `0` for the called application, otherwise the 1-based position — never a raw application identifier, and an undeclared application is appended to `apfa` up to the eight-application limit.
7. The bytes signed and the bytes submitted are produced by the same encoding call, and a transaction identifier is always the hash of the bytes that were signed. For a transaction signed as part of an atomic group that means the encoding including `grp`.

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

### SPEC SECTION Error Cases
| Error | When | Behavior |
|-------|------|----------|
| Invalid address or mnemonic | Input fails protocol validation | Return a typed error without creating an account value |
| Incomplete transaction | A required builder field is absent | Return an error instead of producing a transaction |
| Invalid signature or group | Cryptographic or grouping validation fails | Reject the operation |
| Network failure | A node or indexer request fails or returns invalid data | Surface an asynchronous error |
| Encoding failure | A transaction map exceeds MessagePack's map or array limits | Throw `AlgorandError.encodingError` rather than emit a truncated encoding |
| Too many foreign applications | Box references would extend `apfa` past eight entries | Throw `AlgorandError.invalidTransaction` at encode time rather than let the node reject it |

No new `AlgorandError` case is introduced. A box reference naming an application absent from `apfa` appends that application rather than failing, up to the limit above.

### SPEC SECTION Complete API and source inventory
The active spec maps all 21 canonical Swift source files and documents all 344 unique public symbols extracted by SpecSync 5.0.1. The inventory is organized by accounts and cryptography, canonical protocol encoding, transaction families, atomic grouping, Algod, Indexer, response models, configuration, and errors. The two files added for canonical encoding, `CanonicalTransactionFields.swift` and `CanonicalBoxReferences.swift`, are internal and contribute no public symbol.

## ADDED

### REQUIREMENT REQ-algorand-013
Transaction encoding SHALL omit every field that holds its go-algorand zero value, following the `_struct codec:",omitempty,omitemptyarray"` semantics of go-algorand v5.0.1-stable: unsigned integers when `0`, strings when empty, variable-length byte slices when `len == 0`, fixed-width byte arrays and addresses when every byte is zero, arrays when empty, and nested structures when recursively empty. `snd` and `type` are the only exempt transaction fields.

Acceptance Criteria
- The `pay_fee_zero`, `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`, `pay_empty_genesis_id`, `pay_all_omittable_zero`, and `axfer_zero_asset_id` vectors match byte-for-byte and produce the golden transaction identifier.
- `pay_empty_note` and `pay_zero_lease` produce the same encoding and identifier as `pay_normal`.
- `pay_all_omittable_zero` encodes to 129 bytes carrying only `gh`, `lv`, `rcv`, `snd`, `type`.
- A variable-length byte field whose content is all zeros but non-empty is retained, not omitted.

### REQUIREMENT REQ-algorand-014
Boolean transaction fields — `nonpart`, `afrz`, and `apar.df` — SHALL be encoded as a MessagePack boolean (`0xC3`) and SHALL be omitted entirely when false. No boolean field is encoded as an integer, and `0xC2` is never written.

Acceptance Criteria
- `keyreg_nonparticipating` encodes `a76e6f6e70617274 c3`.
- `keyreg_offline` omits `nonpart`; `afrz_unfreeze` omits `afrz`; `acfg_create_default_frozen_false` omits `apar.df`.
- `afrz_freeze` writes `afrz` as `0xC3`.

### REQUIREMENT REQ-algorand-015
An application call's `apbx` entries SHALL carry a foreign-application slot index, never an application identifier: `0` when the box belongs to the application being called, otherwise the 1-based position of that application in `apfa`. An application named by a box reference but absent from `apfa` SHALL be appended to `apfa` so the index resolves, and SHALL fail with `AlgorandError.invalidTransaction` when that would exceed eight foreign applications. The caller-facing `boxes: [(UInt64, Data)]?` parameter continues to name boxes by owning application identifier. The box name `n` SHALL be omitted when empty.

Acceptance Criteria
- `appl_box_current_app` and `appl_box_self_app_id` omit `i`.
- `appl_box_foreign_app` encodes `i` as `1` and `2`, and the raw identifier byte sequences `ce3ade68b1` and `ce075bcd15` appear only inside `apfa`.
- `appl_box_empty_name` encodes `apbx` as `91 80`.
- `appl_kitchen_sink` matches its 401-byte golden encoding.

### REQUIREMENT REQ-algorand-016
`SignedTransaction.id()` SHALL return the identifier of the bytes that were signed, which for a grouped transaction is the encoding including `grp`. `Transaction.id()` SHALL continue to return the ungrouped identifier, because `AtomicTransactionGroup` derives the group identifier from each member's ungrouped encoding.

Acceptance Criteria
- `group_txn0_grouped` reports `3ZFBH32KQJVFCXLXVRCONWKYXL5R5EENIRHKURR3LFL4UGPD3CFQ` through `SignedTransaction.id()`.
- `AtomicTransactionGroup.groupID` remains `2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899` for the golden two-payment group and is stable across repeated construction.
- The grouped and ungrouped identifiers of the same transaction differ.

### REQUIREMENT REQ-algorand-017
Transactions carrying no zero-valued or empty field SHALL encode to byte-identical output before and after this change, and the omit-empty rules SHALL be enforced at a single internal choke point through which every transaction field passes.

Acceptance Criteria
- All 37 golden vectors passing against the pre-change encoder still pass, unchanged.
- No `encode(groupID:)` implementation assigns directly into a `[String: MessagePackValue]`; every transaction type installs its shared header through the single `setHeader(...)` call.
- `MessagePackWriter` and `MessagePackValue` are unchanged.

### REQUIREMENT REQ-algorand-018
The canonical encoder SHALL be verified by byte-equality golden vectors whose authority is go-algorand v5.0.1-stable's msgp-generated marshaller. py-algorand-sdk SHALL NOT be treated as a byte oracle. No vector or fixture may be copied from an AGPL-3.0 or unlicensed upstream into this MIT package.

Acceptance Criteria
- The suite asserts encoded bytes and transaction identifier against hex literals, not shape or length.
- The three py-algorand-sdk deviations (`apan`, `nonpart`, `lx`) are recorded alongside the vectors that expose them.
- No file under `Tests/` originates in `algorandfoundation/falcon-signatures` or `algorandfoundation/algokit-polytest`.
