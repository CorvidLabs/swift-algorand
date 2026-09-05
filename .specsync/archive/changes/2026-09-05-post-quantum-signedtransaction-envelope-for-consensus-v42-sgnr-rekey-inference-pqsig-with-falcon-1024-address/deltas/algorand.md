# algorand

## MODIFIED

### SPEC SECTION Purpose
Provide the existing Swift SDK primitives for Algorand accounts, addresses, amounts, mnemonics, transactions, signing (Ed25519 and, since consensus v42, native post-quantum Falcon-1024 through a caller-supplied signer), atomic groups, and asynchronous Algod and Indexer clients across the package's supported Apple and Linux platforms.

### SPEC SECTION Public API
### Contract groups

| Existing surface | Contract |
|---|---|
| Accounts, addresses, mnemonics, hashes, and amounts | Validate protocol representations, create or restore keys, sign and verify bytes, and preserve Algorand encodings. |
| Transactions and MessagePack | Build and encode payment, asset, application, and key-registration transactions in go-algorand's canonical omit-empty MessagePack form, with explicit invalid-input failures. |
| Atomic groups and signed transactions | Preserve transaction order, derive one group identifier, sign with the matching accounts or any `TransactionSigner`, carry `sgnr` for a rekeyed sender, carry a Falcon-1024 `pqsig` for a native post-quantum account, and encode submission payloads as go-algorand's omit-empty `SignedTxn` map. |
| `AlgodClient` | Asynchronously read node state, submit transactions, wait for confirmations, inspect applications/assets/boxes, and simulate transaction groups. |
| `IndexerClient` | Asynchronously query indexed accounts, transactions, assets, applications, blocks, pagination, and health. |
| Response models | Decode the currently exposed node/indexer JSON fields into `Codable & Sendable` values without concealing absent optional data. |
| Configuration and errors | Select localnet, TestNet, MainNet, or custom endpoints and surface validation, transport, API, encoding, and decoding failures. |

### Complete Swift export inventory

SpecSync 6.0.0 extracts the following 361 unique public symbols from the 28 canonical Swift source files. Repeated property names appear once because coverage is symbol-name based. The 17 names added by the post-quantum envelope change are listed at the end of the table.

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

No new `AlgorandError` case is introduced. `TransactionAuthorizationError` is the one error type added by the post-quantum envelope change; Ed25519 signature bytes are carried verbatim and never validated locally. A box reference naming an application absent from `apfa` appends that application rather than failing, up to the limit above.

### SPEC SECTION Complete API and source inventory
The active spec maps all 28 canonical Swift source files and documents all 361 unique public symbols extracted by SpecSync 6.0.0. The inventory is organized by accounts and cryptography, canonical protocol encoding, signed-transaction envelopes and post-quantum authorization, transaction families, atomic grouping, Algod, Indexer, response models, configuration, and errors. The two files added for canonical encoding, `CanonicalTransactionFields.swift` and `CanonicalBoxReferences.swift`, and the `Edwards25519.swift` point predicate added for post-quantum address derivation are internal and contribute no public symbol. The other six files added by the post-quantum envelope change (`Address+PostQuantum.swift`, `PQScheme.swift`, `PQSignature.swift`, `Transaction+Signing.swift`, `TransactionAuthorization.swift`, `TransactionSigner.swift`) contribute the 17 names listed at the end of the export inventory.

## ADDED

### REQUIREMENT REQ-algorand-019
`SignedTransaction.encode()` SHALL emit go-algorand's `SignedTxn` envelope as a canonical omit-empty MessagePack map over the keys `lsig < msig < pqsig < sgnr < sig < txn`, writing only the keys that are present, choosing `bin8`, `bin16`, or `bin32` headers by value length through the canonical writer, and splicing the transaction bytes that were signed in under `txn`. An envelope carrying only an Ed25519 signature SHALL encode byte-identically to the previous fixed `0x82 {sig, txn}` encoding, and a signature longer than 255 bytes SHALL encode rather than trap.

Acceptance Criteria
- `testEd25519EnvelopeIsByteIdenticalToLegacyEncoder` and `testGroupedEd25519EnvelopeIsByteIdenticalToLegacyEncoder` match a hand-written legacy `{sig, txn}` layout and the `signed_ed25519_only` golden envelope, standalone and grouped; six envelopes produced by a build of 93c952a and by this change are byte-identical, transaction IDs included.
- `testEnvelopeSurvivesSignaturesLongerThan255Bytes` encodes a 1538-byte value under `sig` with a `bin16` header (`82a3736967c50602`) instead of aborting the process.
- `testSignedEnvelopeStructure`, `testSignedEnvelopeIsByteExactOnDeterministicBackends`, and every pre-existing XCTest signing test pass unchanged in outcome.

*Rationale: the previous encoder hand-wrote `0x82`, `"sig"`, `0xC4`, `UInt8(signature.count)`, which could express neither `sgnr` nor `pqsig` and trapped for every Falcon-1024 signature.*

### REQUIREMENT REQ-algorand-020
Signing SHALL infer `sgnr`: when the signer's address differs from `transaction.sender`, the envelope SHALL carry the signer's address under `sgnr`; when it equals the sender, `sgnr` SHALL be omitted. An explicit `authAddr` argument SHALL be accepted only when it equals the signer's address, and otherwise signing SHALL throw `TransactionAuthorizationError.authAddrMismatch` before any signature is produced. This applies to `SignedTransaction.sign(_:with:groupID:authAddr:)` and to `TransactionSigner.sign(_:groupID:authAddr:)` alike.

Acceptance Criteria
- `testRekeyedEnvelopeCarriesSgnr` and `testSignerDifferentFromSenderInfersSgnr` produce the 280-byte `{sgnr, sig, txn}` envelope of golden vector `signed_ed25519_rekeyed_sgnr`, byte-exact where the Ed25519 backend is deterministic.
- `testSignerEqualToSenderOmitsSgnr`, `testExplicitAuthAddrMustNameTheSigner`, and `testAccountSignsThroughTheProtocolPath` cover omission, the accepted explicit form, and the typed mismatch error on both paths.
- Live: a rekeyed envelope simulated on TestNet v42 returns HTTP 200 with `should have been authorized by <sender> but was actually authorized by <signer>` (the throwaway sender is not rekeyed on chain), which is an authorization failure after a successful decode, not a decode error.

*Rationale: matches py-algorand-sdk and js-algorand-sdk, and consensus (`EnforceAuthAddrSenderDiff`) rejects a `sgnr` equal to the sender, so inference is the only correct policy.*

### REQUIREMENT REQ-algorand-021
`Address.postQuantum(scheme:salt:publicKey:)` SHALL derive `SHA512_256("PQA" || scheme[2] || salt[1] || publicKey)`, and `Address.postQuantum(scheme:publicKey:)` SHALL return the canonical salt and address: the lowest salt in `0...255` whose derived address does not decode as an Edwards25519 point, where the point predicate follows `edwards25519.Point.SetBytes` exactly, accepting non-canonical encodings and not requiring prime-order subgroup membership.

Acceptance Criteria
- `testEdwards25519PointPredicateMatchesGoSetBytes` agrees with all 13 point-decode vectors, including `y == p`, `y == p + 1`, all-zero, all-`0xff`, and the identity with the sign bit set.
- `testPostQuantumAddressDerivationMatchesGoldenVectors` reproduces canonical salts 0, 2, and 1 and the three golden addresses, and shows that every lower salt's digest decodes as a point.
- Live: with the `slt` of a `pqsig` envelope patched from 0 to 1, TestNet v42 rejects it with `pq signature authorizer mismatch: derived 26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA`, which equals `Address.postQuantum(scheme: .falcon1024, salt: 1, publicKey:)` for the same key.

### REQUIREMENT REQ-algorand-022
A post-quantum authorization SHALL be carried as `pqsig: {pk, sch, sig, slt}`, where `sch` is the two-byte scheme tag as a MessagePack binary (`"f1"`, bytes `0x66 0x31`, for Falcon-1024), `slt` is omitted when zero, and `pk` and `sig` are binaries of 1793 and at most 1538 bytes for Falcon-1024. The signing preimage SHALL be `"TX" || msgpack(txn)`, unhashed, exposed as `Transaction.bytesToSign(groupID:)`. Signing SHALL be delegated through the `TransactionSigner` protocol, to which `Account` conforms; `PQSigner` SHALL derive the canonical salt and address from the public key and obtain the signature from a caller-supplied `@Sendable` callback. No Falcon implementation SHALL be bundled.

Acceptance Criteria
- `testPostQuantumSignedEnvelopeMatchesGoldenVector` reproduces the 3530-byte `pq_signed_payment` envelope from its parts and its transaction ID `BT6JAPZ7LE75FHLMO624E2J7WXBG7POEL6EKOCJAGVJNGCSLKYXA`.
- `testPostQuantumSaltIsOmittedWhenZeroAndPresentOtherwise`, `testPostQuantumSignerDerivesCanonicalSaltAndAddress`, `testCustomSignerReceivesThePreimageAndControlsSgnr`, `testBytesToSignIsThePrefixedCanonicalEncoding`, and `testPostQuantumSchemeTag` pass.
- Live: a `pqsig` envelope with `sch = "f1"` simulated on TestNet v42 is rejected at signature verification (`pq signature validation failed: invalid falcon-1024 signature: error code -4: falcon verify failed`), past the scheme check that answered `pq signature scheme not supported` for every other tag, and past the authorizer check.

*Rationale: `protocol.PQSchemeFalcon1024 = PQScheme{'f', '1'}` in go-algorand v5.0.1-stable (`protocol/pq_scheme.go`); `[2]byte` marshals as a binary.*

### REQUIREMENT REQ-algorand-023
Before a signed transaction is assembled, and again when it is encoded, a post-quantum proof SHALL be verified to authorize the transaction: its public key has the scheme's size, its signature is non-empty and within the scheme's maximum, and its scheme, salt, and public key derive the authorizer, which is `sgnr` when present and otherwise the sender. Violations SHALL throw `TransactionAuthorizationError.unauthorizedProof` or `TransactionAuthorizationError.malformed`. Ed25519 signature bytes SHALL be carried verbatim.

Acceptance Criteria
- `testPostQuantumProofMustDeriveTheAuthorizer` covers sign-time refusal of a proof for another key, refusal of a non-canonical salt, encode-time refusal of a hand-built envelope, and acceptance of the same proof once `sgnr` names the derived address.
- `testPostQuantumSizesAreEnforced`, `testRekeyedPostQuantumSignerCarriesSgnr`, and `testAuthorizationErrorsDescribeThemselves` pass.
- No `AlgorandError` case is added; `TransactionAuthorizationError` is the only new error type.
