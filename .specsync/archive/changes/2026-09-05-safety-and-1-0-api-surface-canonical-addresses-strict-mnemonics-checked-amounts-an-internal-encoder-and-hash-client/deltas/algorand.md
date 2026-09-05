# algorand

## MODIFIED

### SPEC SECTION Purpose
Provide the existing Swift SDK primitives for Algorand accounts, canonical addresses and mnemonics, checked amounts, transactions priced under the consensus v42 usage-based fee model, signing (Ed25519 and, since consensus v42, native post-quantum Falcon-1024 through a caller-supplied signer), atomic groups with a pooled fee requirement, and asynchronous Algod and Indexer clients whose requests reach the endpoints they name, across the package's supported Apple and Linux platforms.

### SPEC SECTION Public API
### Contract groups

| Existing surface | Contract |
|---|---|
| Accounts, addresses, mnemonics, and amounts | Accept only canonical address and mnemonic representations, create or restore keys held in the cryptography library's own storage, sign and verify bytes, preserve Algorand encodings, and offer checked amount arithmetic and conversion that throws `AmountError` where the deprecated operators trap. |
| Transactions and MessagePack | Build and encode payment, asset, application, and key-registration transactions in go-algorand's canonical omit-empty MessagePack form, price their fees with a `FeeStrategy` against suggested parameters under the consensus v42 usage model, with explicit invalid-input failures. |
| Atomic groups and signed transactions | Preserve transaction order, derive one group identifier, report the group's pooled consensus v42 fee usage and requirement, sign with the matching accounts or any `TransactionSigner`, carry `sgnr` for a rekeyed sender, carry a Falcon-1024 `pqsig` for a native post-quantum account, and encode submission payloads as go-algorand's omit-empty `SignedTxn` map. |
| `AlgodClient` | Asynchronously read node state, submit transactions, wait for confirmations through the node's 404 for an unseen transaction, inspect applications/assets/boxes by raw box name, and simulate transaction groups over `application/msgpack`. |
| `IndexerClient` | Asynchronously query indexed accounts, transactions, assets, applications, blocks, pagination, and health. |
| Response models | Decode the currently exposed node/indexer JSON fields into `Codable & Sendable` values without concealing absent optional data. |
| Configuration and errors | Select localnet, TestNet, MainNet, or custom endpoints without a force-unwrapped URL, and surface validation, URL, transport, API, encoding, decoding, and amount failures. |

### Complete Swift export inventory

SpecSync 6.0.0 extracts the following 384 unique public symbols from the 36 canonical Swift source files. Repeated property names appear once because coverage is symbol-name based. The 17 names added by the post-quantum envelope change, the 17 names added by the consensus v42 fee-model change, and the 17 names added by the safety and 1.0 API-surface change are listed at the end of the table, in that order. The safety change also removed 11 names: `MessagePackWriter`, `write`, `MessagePackValue`, `string`, `binary`, `map`, `array`, `bool`, and `SHA512_256` became internal, and `PendingTransaction.txn` and the empty `TransactionData` were removed.

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
| `assetIndex` |
| `applicationIndex` |
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
| `invalidURL` |
| `AmountError` |
| `divisionByZero` |
| `notRepresentable` |
| `microAlgosPerAlgo` |
| `subtracting` |
| `multiplied` |
| `divided` |
| `baseUnits` |
| `defaultLocalnetAPIToken` |
| `timestamp` |
| `previousBlockHash` |
| `seed` |
| `transactionsRoot` |
| `transactionsRootSha256` |
| `txnCounter` |
| `proposer` |

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
11. `Address(string:)` accepts exactly the strings go-algorand's `UnmarshalChecksumAddress` accepts: 58 characters of the uppercase base32 alphabet whose 36 decoded bytes pass the checksum and re-encode to the identical string, so `description` is always canonical. `Mnemonic.decode` accepts exactly the phrases py-algorand-sdk's `to_private_key` accepts: 25 wordlist words whose 24 key words unpack to 33 bytes with the 33rd zero and whose 25th word is the checksum.
12. Amount arithmetic in the public surface never traps on caller input: the checked `MicroAlgos` forms, `MicroAlgos.init(checkedAlgos:)`, and `AssetParams.baseUnits(for:)` throw `AmountError`, while the trapping operators, `init(algos:)`, and `toBaseUnits(_:)` remain, deprecated, with their original semantics. No library code force-unwraps, and no library code uses a deprecated symbol.
13. `MessagePackWriter`, `MessagePackValue`, and `SHA512_256` are internal; the canonical MessagePack writer can splice a pre-encoded value verbatim through `MessagePackValue.raw`, which is how a signed transaction's own bytes reach `POST /v2/transactions/simulate`. Transaction and envelope encodings are byte-identical to every previous release.
14. `Account` holds its key as a `Curve25519.Signing.PrivateKey` and never as a `Data` copy of the seed; the seed is materialised as bytes only by `mnemonic()`. SECURITY.md describes what the cryptography library's storage does and does not guarantee and never presents zeroing as a security boundary.
15. `AlgodClient.waitForConfirmation` treats HTTP 404 from `GET /v2/transactions/pending/{id}` as "not seen yet" and keeps polling in the same query-then-wait order; `applicationBox` builds `?name=b64:<base64>` through `URLComponents` with the value percent-encoded to the unreserved set; a client base URL must be an absolute http(s) URL or `AlgorandError.invalidURL` is thrown; `AlgorandConfiguration`'s well-known factories throw rather than force-unwrap their endpoint literals.

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

```
Given a canonical TestNet address and its lowercase and stray-trailing-bit variants
When each is passed to Address(string:)
Then only the canonical string is accepted, its description equals the input, and the variants throw AlgorandError.invalidAddress although their checksums pass
```

```
Given a 32-byte key and the 256 spellings of its 25-word mnemonic that share a checksum
When each is passed to Mnemonic.decode
Then only the spelling whose 33rd unpacked byte is zero decodes, and the other 255 throw AlgorandError.invalidMnemonic
```

```
Given an unfunded throwaway account and suggested parameters from a consensus v42 node
When a payment is signed, wrapped in a SimulateRequestTransactionGroup, and posted through simulateTransaction
Then the node answers HTTP 200 and the decoded group reports overspend for the sender in failure-message, past decoding and signature verification
```

```
Given a transaction identifier the node has not seen
When waitForConfirmation polls with a timeout of one round
Then the node's 404 is tolerated, the client waits for the round, and it throws networkError("Transaction not confirmed after 1 rounds") rather than apiError(404)
```

### SPEC SECTION Error Cases
| Error | When | Behavior |
|-------|------|----------|
| Invalid or non-canonical address or mnemonic | Input fails protocol validation or is not the canonical rendering | Return `AlgorandError.invalidAddress` or `AlgorandError.invalidMnemonic` without creating a value |
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
| Amount overflow or division by zero | A checked `MicroAlgos` sum, difference, or product leaves `UInt64`, or the divisor is zero | Throw `AmountError.overflow` or `AmountError.divisionByZero` rather than trap |
| Unrepresentable amount | A `Double` passed to `MicroAlgos(checkedAlgos:)` or `AssetParams.baseUnits(for:)` is NaN, infinite, negative, or scales to 2^64 or more | Throw `AmountError.notRepresentable` rather than trap |
| Invalid URL | A client base URL is not an absolute http(s) URL, or a request URL cannot be assembled from its components | Throw `AlgorandError.invalidURL` |
| Transaction not yet known | `GET /v2/transactions/pending/{id}` answers 404 during confirmation polling | Keep polling; throw `networkError` only when the timeout elapses |

`AlgorandError.invalidURL` is the one `AlgorandError` case added, by the safety and 1.0 API-surface change, which also added `AmountError`. `TransactionAuthorizationError` is the one error type added by the post-quantum envelope change and `FeeError` the one added by the fee-model change; Ed25519 signature bytes are carried verbatim and never validated locally. A box reference naming an application absent from `apfa` appends that application rather than failing, up to the limit above.

### SPEC SECTION Complete API and source inventory
The active spec maps all 36 canonical Swift source files and documents all 384 unique public symbols extracted by SpecSync 6.0.0. The inventory is organized by accounts and cryptography, canonical protocol encoding, signed-transaction envelopes and post-quantum authorization, the consensus v42 fee model, transaction families, atomic grouping, Algod, Indexer, response models, configuration, and errors. The two files added for canonical encoding, `CanonicalTransactionFields.swift` and `CanonicalBoxReferences.swift`, and the `Edwards25519.swift` point predicate added for post-quantum address derivation are internal and contribute no public symbol. The other six files added by the post-quantum envelope change (`Address+PostQuantum.swift`, `PQScheme.swift`, `PQSignature.swift`, `Transaction+Signing.swift`, `TransactionAuthorization.swift`, `TransactionSigner.swift`) contribute the 17 names listed after the original inventory. The five files added by the consensus v42 fee-model change (`AlgorandConsensus.swift`, `AtomicTransactionGroup+Fees.swift`, `FeeError.swift`, `FeeStrategy.swift`, `TransactionUsage.swift`) contribute the 17 names listed after those. The safety and 1.0 API-surface change added three files: `AmountError.swift` contributes `AmountError`, `divisionByZero`, and `notRepresentable`; `EndpointURL.swift` and `SimulateRequest+MessagePack.swift` are internal and contribute no public symbol. Its other 14 new names come from `MicroAlgos.swift`, `AssetTransaction.swift`, `AlgorandError.swift`, `AlgorandConfiguration.swift`, and `IndexerClient.swift`, and it made `MessagePackWriter.swift` and `SHA512_256.swift` contribute no public symbol. `Package.swift` and the DocC catalog under `Sources/Algorand/Algorand.docc` are exact-only delivery inputs of the still-accepted CHG-0001 and are unchanged by this change.

## ADDED

### REQUIREMENT REQ-algorand-029
`Address.init(string:)` SHALL accept a string only if it has 58 characters of the uppercase RFC 4648 base32 alphabet, its 36 decoded bytes carry a valid SHA-512/256 checksum, and re-encoding those bytes reproduces the input exactly, which is go-algorand's `UnmarshalChecksumAddress` rule; otherwise it SHALL throw `AlgorandError.invalidAddress`. `description` SHALL be the canonical rendering, and `Address.init(bytes:)` SHALL produce a string `init(string:)` accepts.

Acceptance Criteria
- `canonicalAddressRoundTrips`, `lowercaseAddressesAreRejected`, `nonCanonicalTrailingBitsAreRejected` (the three same-checksum variants of a real TestNet address whose final character carries stray bits), `malformedAddressesAreRejected`, and `addressDecodesFromJSONCanonicallyOnly` pass.
- The legacy `AddressTests` pass unchanged, and no frozen test asserts a lowercase address.

*Rationale: the previous decoder folded case and dropped trailing bits, so four distinct strings decoded to one address and `description` could be a string no other Algorand tool accepts.*

### REQUIREMENT REQ-algorand-030
`Mnemonic.decode` SHALL unpack the 24 key words to 33 bytes and SHALL throw `AlgorandError.invalidMnemonic` unless the 33rd byte is zero, the check py-algorand-sdk's `to_private_key` makes, before verifying the checksum word; `Mnemonic.isValid` and `Account.init(mnemonic:)` SHALL follow. Every mnemonic `Mnemonic.encode` and `Mnemonic.generate` produce SHALL be canonical.

Acceptance Criteria
- `nonCanonicalMnemonicsAreRejected` shows all 255 non-canonical spellings of a key rejected with a message containing `Non-canonical` and the canonical spelling accepted.
- `crossSDKMnemonicVectorsStillDecode` keeps the all-zero and all-42 py-algorand-sdk vectors, `malformedMnemonicsAreRejected` and `generatedMnemonicsRoundTrip` pass, and the legacy `MnemonicTests` (6 tests) pass unchanged, so nothing depended on lenient decoding.

### REQUIREMENT REQ-algorand-031
`MicroAlgos` SHALL offer `adding(_:)`, `subtracting(_:)`, `multiplied(by:)`, and `divided(by:)`, which throw `AmountError.overflow` or `AmountError.divisionByZero` where `+`, `-`, `*`, and `/` trap, and `init(checkedAlgos:)`, which rounds to the nearest microAlgo and throws `AmountError.notRepresentable` for a NaN, infinite, negative, or out-of-range value. `AssetParams` SHALL offer `baseUnits(for:)` with the same contract. The operators, `init(algos:)`, and `toBaseUnits(_:)` SHALL remain with unchanged semantics, marked `@available(*, deprecated)` with a message naming the replacement, and no library code SHALL use them.

Acceptance Criteria
- `checkedArithmeticHappyPath`, `checkedArithmeticThrowsInsteadOfTrapping`, `checkedAlgosInitializer` (including 2^64 microAlgos exactly), `assetBaseUnits` (including `Double(UInt64.max)`, which rounds to 2^64), and `amountErrorsDescribeThemselves` pass.
- The legacy `MicroAlgosTests`, `AssetTests`, `IntegrationTests`, and `ComprehensiveIntegrationTest` compile and pass unchanged through the deprecated symbols; their deprecation warnings are the only ones in the test build, and a forced full recompile of `Sources/Algorand` emits none.
- The fee-model files (`FeeStrategy.swift`, `TransactionUsage.swift`, `AtomicTransactionGroup+Fees.swift`) are unchanged from the base tree and use no deprecated symbol.

### REQUIREMENT REQ-algorand-032
`MessagePackWriter`, `MessagePackValue`, and `SHA512_256` SHALL be `internal`, and `MessagePackValue` SHALL gain `case raw(Data)`, which the writer splices verbatim. Every transaction, envelope, and group-identifier encoding SHALL be byte-identical to the base tree.

Acceptance Criteria
- `specsync check --strict` reports 384/384 exports documented with no row for `MessagePackWriter`, `write`, `MessagePackValue`, `string`, `binary`, `map`, `array`, `bool`, or `SHA512_256`.
- `rawValuesAreSplicedVerbatim` passes, and the golden-vector suites `CanonicalEncodingTests`, `CanonicalBoxReferenceTests`, `SignedTransactionEnvelopeTests`, `PostQuantumVectorTests`, and `FeeModelTests` pass unchanged, byte-for-byte.

### REQUIREMENT REQ-algorand-033
`AlgorandError` SHALL gain `invalidURL(String)`, thrown by `AlgodClient.init(baseURL: String)` and `IndexerClient.init(baseURL: String)` for anything but an absolute http(s) URL and by request construction that cannot assemble a URL. `AlgodClient.applicationBox(_:name:)` SHALL take the raw box name as `Data` and request `/v2/applications/{id}/box?name=b64:<base64>` with the value percent-encoded to the unreserved set. `simulateTransaction` SHALL post `Content-Type: application/msgpack` with the body `{"txn-groups":[{"txns":[<raw signed txns>]}]}` plus only the flags that are set, and decode the JSON response; `SimulateRequestTransactionGroup.txns` SHALL be `[Data]` with an `init(signedTransactions:)`. `waitForConfirmation` SHALL treat the node's 404 as "not yet" without reordering the poll and SHALL throw `AlgorandError.invalidTransaction` if `timeout` overflows the round counter. No library code SHALL force-unwrap. `PendingTransaction.txn` and `TransactionData` SHALL be removed; `BlockResponse` SHALL carry the block header and its transactions; `IndexerAsset.params` SHALL be an `AssetParamsResponse` with a deprecated `IndexerAsset.AssetParams` typealias.

Acceptance Criteria
- `invalidBaseURLsAreInvalidURL`, `builtInEndpointsResolve`, `boxURLIsWellFormed` (`?name=b64%3A%2B%2F8%3D`, no `%3F`), `simulateBodyIsMessagePack` (exact bytes), `simulateFlagsAreOmittedOrCanonical`, `simulateGroupFromSignedTransactions`, `responsesDecode`, `blockResponseDecodes`, `indexerAssetDecodesFullParameters`, and `notYetKnownMatchesOnly404` pass.
- The serialized `Transport` suite passes through a `URLProtocol` stub: `waitForConfirmationToleratesA404` (status, 404, wait-for-block, confirmed, in that order), `waitForConfirmationSurfacesOtherFailures`, `waitForConfirmationRejectsOverflowingTimeout`, `applicationBoxSendsALiveQueryURL`, and `simulatePostsMessagePack` (`Content-Type: application/msgpack`, body equal to the encoder's output).
- Live, read-only, on TestNet v42: a payment signed by an unfunded throwaway account simulates with HTTP 200 and `failure-message` `overspend`; `GET /v2/transactions/pending/{unknown}` answers 404 and `waitForConfirmation(timeout: 1)` then throws `networkError("Transaction not confirmed after 1 rounds")`; `applicationBox` on an application with a box whose base64 name contains `+` returns the box, while the base tree's `%3F` URL answers the router's `{"message":"Not Found"}`.
- `grep -rn '!' Sources/Algorand` finds no force unwrap, `try!`, or `as!`.

### REQUIREMENT REQ-algorand-034
`Account` SHALL store its key as a `Curve25519.Signing.PrivateKey` inside a private reference-typed box, SHALL never hold a `Data` copy of the seed, and SHALL keep its public API (`init()`, `init(mnemonic:)`, `init(privateKey:)`, `mnemonic()`, `sign(_:)`, `verify(signature:for:)`, `address`, `publicKey`). Root `SECURITY.md` SHALL state what the key storage guarantees on each platform (swift-crypto's `SecureBytes` with `memset_s` on Linux, backed by BoringSSL; CryptoKit on Apple platforms), what it does not (caller-owned copies, swap, core dumps, a process that can read memory), and SHALL never present zeroing as a security boundary.

Acceptance Criteria
- `accountKeyStorageIsStable` shows a key surviving `mnemonic()` by cross-verification, a mnemonic round trip restoring the same address and public key, and a copied `Account` signing for the same key; `AccountTests`, `CanonicalEncodingTests`, and `SignedTransactionEnvelopeTests` keep every existing signature vector.
- `SECURITY.md` and `documentation/SECURITY.md` contain no claim that the SDK zeroes key material as a boundary, and name BoringSSL for Linux.
