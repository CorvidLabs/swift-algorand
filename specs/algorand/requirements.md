---
spec: algorand.spec.md
---

## Requirements

### REQ-algorand-001

`Account`, `Address`, and `Mnemonic` SHALL preserve Algorand key generation, recovery, checksum validation, signing, signature verification, and human-readable encoding behavior.

Acceptance Criteria
- Existing account, address, and mnemonic unit tests pass, including invalid input and round-trip cases.

### REQ-algorand-002

`MicroAlgos`, `SHA512_256`, secure randomness, and MessagePack encoding SHALL preserve protocol-compatible numeric, hash, random-byte, and canonical wire representations. Canonical means the encoding produced by go-algorand v5.0.1-stable's msgp-generated marshaller under `_struct codec:",omitempty,omitemptyarray"`, so that the bytes this package signs are the bytes a consensus v42 node reconstructs and verifies.

Acceptance Criteria
- Amount arithmetic and conversion, official hash vectors, and generated randomness use tests pass.
- The canonical golden-vector suite passes by byte equality of the encoded transaction and the base32 transaction identifier against vectors derived from go-algorand v5.0.1-stable.

*Rationale: the requirement text was already correct and the code already violated it. `fee`, `fv`, `gen`, `note`, and `lx` were emitted when zero or empty, and TestNet returned `HTTP 400 {"message":"At least one signature didn't pass verification"}`. The former acceptance criterion, "transaction encoding tests pass", was satisfiable by tests asserting `encoded.count > 0`.*

### REQ-algorand-003

Base and signed transaction values SHALL preserve transaction identifiers, validity rounds, fees, genesis data, notes, leases, rekeying, signatures, and deterministic encoding failures.

Acceptance Criteria
- Transaction identifier, signing, encoding, and invalid-construction tests pass.

### REQ-algorand-004

Payment construction SHALL require sender, receiver, amount, and suggested parameters and SHALL preserve note, lease, rekey, close-out, and custom-validity behavior.

Acceptance Criteria
- Payment builder, zero and nonzero amount encoding, signing, and close-out tests pass.

### REQ-algorand-005

Asset creation, opt-in, freeze, configuration, destruction, transfer, close-out, and clawback transactions SHALL encode their existing Algorand asset fields and strict empty-address policy.

Acceptance Criteria
- Existing asset creation, management, transfer, opt-in, freeze, update, destroy, close-out, and signing tests pass.

### REQ-algorand-006

Application create, update, delete, opt-in, close-out, clear-state, and call transactions SHALL preserve programs, schemas, arguments, accounts, foreign references, boxes, completion mode, and extra-page fields, naming box references by owning application identifier and translating them to `apfa` slot indexes at encode time.

Acceptance Criteria
- Existing application transaction construction, encoding, foreign-reference, box, and signing tests pass.
- The `appl_*` golden vectors match byte-for-byte.

*Rationale: `boxes: [(UInt64, Data)]?` keeps its type and its documented `(app_id, box_name)` meaning. Only the encoder changes, to honour that meaning instead of writing the identifier into the wire index slot.*

### REQ-algorand-007

Key-registration construction SHALL preserve online, offline, and nonparticipating vote, selection, dilution, state-proof, and participation fields, encoding `nonpart` as a MessagePack boolean and omitting it when false.

Acceptance Criteria
- Existing online, offline, nonparticipating, and signing tests pass.
- The `keyreg_nonparticipating` golden vector matches byte-for-byte, carrying `a76e6f6e70617274 c3`.
- The `keyreg_offline` golden vector omits `nonpart` entirely rather than encoding `false`.

*Rationale: `KeyRegistrationTransaction.encode` wrote `nonpart` as MessagePack `uint 1` (`0x01`). go-algorand writes it with `msgp.AppendBool` and reads it with `msgp.ReadBoolBytes`. A nonparticipating key registration built by this package could not be accepted by any node.*

### REQ-algorand-008

Atomic groups SHALL reject empty or oversized groups, preserve transaction order, assign one deterministic group identifier, require matching signing accounts, and encode the signed sequence.

Acceptance Criteria
- Existing empty, size-limit, ordering, deterministic-ID, mixed-type, signing-account, and encoding tests pass.

### REQ-algorand-009

`AlgodClient` SHALL asynchronously expose node status, round waiting, suggested parameters, transaction submission and confirmation, account/application/box/asset reads, and simulation while surfacing transport, API, and decoding failures.

Acceptance Criteria
- Swift compilation validates the complete async public surface; live node calls remain outside the deterministic pull-request lane.

### REQ-algorand-010

`IndexerClient` SHALL asynchronously expose health and paginated account, transaction, asset, application, and block queries while preserving optional response fields and error propagation.

Acceptance Criteria
- Swift compilation validates the complete async query and response surface; live indexer calls remain outside the deterministic pull-request lane.

### REQ-algorand-011

Network configuration, errors, clients, and response models SHALL preserve the declared localnet, TestNet, MainNet, custom-endpoint, `Sendable`, `Codable`, and typed-failure contracts.

Acceptance Criteria
- Swift 6 builds on the existing platform workflows and existing configuration, decoding, and error tests pass.

### REQ-algorand-012

Native verification SHALL build the package and run its deterministic CI-bounded suite without starting LocalNet, using credentials, sending TestNet transactions, publishing DocC, or releasing artifacts.

Acceptance Criteria
- `swift build` and `CI=true swift test` pass, while the Trust lane contains no localnet startup, credential, send, documentation publication, or release step.

## Constraints

- Supported platform minimums and Swift 6 package compatibility remain as declared in `Package.swift`.
- Transaction encoding conforms to go-algorand v5.0.1-stable's canonical omit-empty MessagePack form; a change that alters the bytes of a well-formed transaction is a protocol-conformance change and needs its own golden vectors.
- Live networks and transaction submission require independently authorized access.

## Out of Scope

- Changing platform minimums, releases, or network credentials.
- The v42 fee model; the `SignedTransaction` authorization envelope (`sig` / `sgnr` / `msig` / `lsig` / `pqsig`); the v41 `al` access list and `aprv` reject-version fields; and the heartbeat and state-proof transaction types. Their golden vectors are recorded in `DeferredVectors.swift` or by name; each follow-up change adds its own test file.
- Client-side enforcement of `MaxAppTotalTxnReferences`; only the foreign-application count is checked, because that is the array the encoder writes into.

### REQ-algorand-013

Transaction encoding SHALL omit every field that holds its go-algorand zero value, following the `_struct codec:",omitempty,omitemptyarray"` semantics of go-algorand v5.0.1-stable: unsigned integers when `0`, strings when empty, variable-length byte slices when `len == 0`, fixed-width byte arrays and addresses when every byte is zero, arrays when empty, and nested structures when recursively empty. `snd` and `type` are the only exempt transaction fields.

Acceptance Criteria
- The `pay_fee_zero`, `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`, `pay_empty_genesis_id`, `pay_all_omittable_zero`, and `axfer_zero_asset_id` vectors match byte-for-byte and produce the golden transaction identifier.
- `pay_empty_note` and `pay_zero_lease` produce the same encoding and identifier as `pay_normal`.
- `pay_all_omittable_zero` encodes to 129 bytes carrying only `gh`, `lv`, `rcv`, `snd`, `type`.
- A variable-length byte field whose content is all zeros but non-empty is retained, not omitted.

### REQ-algorand-014

Boolean transaction fields — `nonpart`, `afrz`, and `apar.df` — SHALL be encoded as a MessagePack boolean (`0xC3`) and SHALL be omitted entirely when false. No boolean field is encoded as an integer, and `0xC2` is never written.

Acceptance Criteria
- `keyreg_nonparticipating` encodes `a76e6f6e70617274 c3`.
- `keyreg_offline` omits `nonpart`; `afrz_unfreeze` omits `afrz`; `acfg_create_default_frozen_false` omits `apar.df`.
- `afrz_freeze` writes `afrz` as `0xC3`.

### REQ-algorand-015

An application call's `apbx` entries SHALL carry a foreign-application slot index, never an application identifier: `0` when the box belongs to the application being called, otherwise the 1-based position of that application in `apfa`. An application named by a box reference but absent from `apfa` SHALL be appended to `apfa` so the index resolves, and SHALL fail with `AlgorandError.invalidTransaction` when that would exceed eight foreign applications. The caller-facing `boxes: [(UInt64, Data)]?` parameter continues to name boxes by owning application identifier. The box name `n` SHALL be omitted when empty.

Acceptance Criteria
- `appl_box_current_app` and `appl_box_self_app_id` omit `i`.
- `appl_box_foreign_app` encodes `i` as `1` and `2`, and the raw identifier byte sequences `ce3ade68b1` and `ce075bcd15` appear only inside `apfa`.
- `appl_box_empty_name` encodes `apbx` as `91 80`.
- `appl_kitchen_sink` matches its 401-byte golden encoding.

### REQ-algorand-016

`SignedTransaction.id()` SHALL return the identifier of the bytes that were signed, which for a grouped transaction is the encoding including `grp`. `Transaction.id()` SHALL continue to return the ungrouped identifier, because `AtomicTransactionGroup` derives the group identifier from each member's ungrouped encoding.

Acceptance Criteria
- `group_txn0_grouped` reports `3ZFBH32KQJVFCXLXVRCONWKYXL5R5EENIRHKURR3LFL4UGPD3CFQ` through `SignedTransaction.id()`.
- `AtomicTransactionGroup.groupID` remains `2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899` for the golden two-payment group and is stable across repeated construction.
- The grouped and ungrouped identifiers of the same transaction differ.

### REQ-algorand-017

Transactions carrying no zero-valued or empty field SHALL encode to byte-identical output before and after this change, and the omit-empty rules SHALL be enforced at a single internal choke point through which every transaction field passes.

Acceptance Criteria
- All 37 golden vectors passing against the pre-change encoder still pass, unchanged.
- No `encode(groupID:)` implementation assigns directly into a `[String: MessagePackValue]`; every transaction type installs its shared header through the single `setHeader(...)` call.
- `MessagePackWriter` and `MessagePackValue` are unchanged.

### REQ-algorand-018

The canonical encoder SHALL be verified by byte-equality golden vectors whose authority is go-algorand v5.0.1-stable's msgp-generated marshaller. py-algorand-sdk SHALL NOT be treated as a byte oracle. No vector or fixture may be copied from an AGPL-3.0 or unlicensed upstream into this MIT package.

Acceptance Criteria
- The suite asserts encoded bytes and transaction identifier against hex literals, not shape or length.
- The three py-algorand-sdk deviations (`apan`, `nonpart`, `lx`) are recorded alongside the vectors that expose them.
- No file under `Tests/` originates in `algorandfoundation/falcon-signatures` or `algorandfoundation/algokit-polytest`.

### REQ-algorand-019

`SignedTransaction.encode()` SHALL emit go-algorand's `SignedTxn` envelope as a canonical omit-empty MessagePack map over the keys `lsig < msig < pqsig < sgnr < sig < txn`, writing only the keys that are present, choosing `bin8`, `bin16`, or `bin32` headers by value length through the canonical writer, and splicing the transaction bytes that were signed in under `txn`. An envelope carrying only an Ed25519 signature SHALL encode byte-identically to the previous fixed `0x82 {sig, txn}` encoding, and a signature longer than 255 bytes SHALL encode rather than trap.

Acceptance Criteria
- `testEd25519EnvelopeIsByteIdenticalToLegacyEncoder` and `testGroupedEd25519EnvelopeIsByteIdenticalToLegacyEncoder` match a hand-written legacy `{sig, txn}` layout and the `signed_ed25519_only` golden envelope, standalone and grouped; six envelopes produced by a build of 93c952a and by this change are byte-identical, transaction IDs included.
- `testEnvelopeSurvivesSignaturesLongerThan255Bytes` encodes a 1538-byte value under `sig` with a `bin16` header (`82a3736967c50602`) instead of aborting the process.
- `testSignedEnvelopeStructure`, `testSignedEnvelopeIsByteExactOnDeterministicBackends`, and every pre-existing XCTest signing test pass unchanged in outcome.

*Rationale: the previous encoder hand-wrote `0x82`, `"sig"`, `0xC4`, `UInt8(signature.count)`, which could express neither `sgnr` nor `pqsig` and trapped for every Falcon-1024 signature.*

### REQ-algorand-020

Signing SHALL infer `sgnr`: when the signer's address differs from `transaction.sender`, the envelope SHALL carry the signer's address under `sgnr`; when it equals the sender, `sgnr` SHALL be omitted. An explicit `authAddr` argument SHALL be accepted only when it equals the signer's address, and otherwise signing SHALL throw `TransactionAuthorizationError.authAddrMismatch` before any signature is produced. This applies to `SignedTransaction.sign(_:with:groupID:authAddr:)` and to `TransactionSigner.sign(_:groupID:authAddr:)` alike.

Acceptance Criteria
- `testRekeyedEnvelopeCarriesSgnr` and `testSignerDifferentFromSenderInfersSgnr` produce the 280-byte `{sgnr, sig, txn}` envelope of golden vector `signed_ed25519_rekeyed_sgnr`, byte-exact where the Ed25519 backend is deterministic.
- `testSignerEqualToSenderOmitsSgnr`, `testExplicitAuthAddrMustNameTheSigner`, and `testAccountSignsThroughTheProtocolPath` cover omission, the accepted explicit form, and the typed mismatch error on both paths.
- Live: a rekeyed envelope simulated on TestNet v42 returns HTTP 200 with `should have been authorized by <sender> but was actually authorized by <signer>` (the throwaway sender is not rekeyed on chain), which is an authorization failure after a successful decode, not a decode error.

*Rationale: matches py-algorand-sdk and js-algorand-sdk, and consensus (`EnforceAuthAddrSenderDiff`) rejects a `sgnr` equal to the sender, so inference is the only correct policy.*

### REQ-algorand-021

`Address.postQuantum(scheme:salt:publicKey:)` SHALL derive `SHA512_256("PQA" || scheme[2] || salt[1] || publicKey)`, and `Address.postQuantum(scheme:publicKey:)` SHALL return the canonical salt and address: the lowest salt in `0...255` whose derived address does not decode as an Edwards25519 point, where the point predicate follows `edwards25519.Point.SetBytes` exactly, accepting non-canonical encodings and not requiring prime-order subgroup membership.

Acceptance Criteria
- `testEdwards25519PointPredicateMatchesGoSetBytes` agrees with all 13 point-decode vectors, including `y == p`, `y == p + 1`, all-zero, all-`0xff`, and the identity with the sign bit set.
- `testPostQuantumAddressDerivationMatchesGoldenVectors` reproduces canonical salts 0, 2, and 1 and the three golden addresses, and shows that every lower salt's digest decodes as a point.
- Live: with the `slt` of a `pqsig` envelope patched from 0 to 1, TestNet v42 rejects it with `pq signature authorizer mismatch: derived 26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA`, which equals `Address.postQuantum(scheme: .falcon1024, salt: 1, publicKey:)` for the same key.

### REQ-algorand-022

A post-quantum authorization SHALL be carried as `pqsig: {pk, sch, sig, slt}`, where `sch` is the two-byte scheme tag as a MessagePack binary (`"f1"`, bytes `0x66 0x31`, for Falcon-1024), `slt` is omitted when zero, and `pk` and `sig` are binaries of 1793 and at most 1538 bytes for Falcon-1024. The signing preimage SHALL be `"TX" || msgpack(txn)`, unhashed, exposed as `Transaction.bytesToSign(groupID:)`. Signing SHALL be delegated through the `TransactionSigner` protocol, to which `Account` conforms; `PQSigner` SHALL derive the canonical salt and address from the public key and obtain the signature from a caller-supplied `@Sendable` callback. No Falcon implementation SHALL be bundled.

Acceptance Criteria
- `testPostQuantumSignedEnvelopeMatchesGoldenVector` reproduces the 3530-byte `pq_signed_payment` envelope from its parts and its transaction ID `BT6JAPZ7LE75FHLMO624E2J7WXBG7POEL6EKOCJAGVJNGCSLKYXA`.
- `testPostQuantumSaltIsOmittedWhenZeroAndPresentOtherwise`, `testPostQuantumSignerDerivesCanonicalSaltAndAddress`, `testCustomSignerReceivesThePreimageAndControlsSgnr`, `testBytesToSignIsThePrefixedCanonicalEncoding`, and `testPostQuantumSchemeTag` pass.
- Live: a `pqsig` envelope with `sch = "f1"` simulated on TestNet v42 is rejected at signature verification (`pq signature validation failed: invalid falcon-1024 signature: error code -4: falcon verify failed`), past the scheme check that answered `pq signature scheme not supported` for every other tag, and past the authorizer check.

*Rationale: `protocol.PQSchemeFalcon1024 = PQScheme{'f', '1'}` in go-algorand v5.0.1-stable (`protocol/pq_scheme.go`); `[2]byte` marshals as a binary.*

### REQ-algorand-023

Before a signed transaction is assembled, and again when it is encoded, a post-quantum proof SHALL be verified to authorize the transaction: its public key has the scheme's size, its signature is non-empty and within the scheme's maximum, and its scheme, salt, and public key derive the authorizer, which is `sgnr` when present and otherwise the sender. Violations SHALL throw `TransactionAuthorizationError.unauthorizedProof` or `TransactionAuthorizationError.malformed`. Ed25519 signature bytes SHALL be carried verbatim.

Acceptance Criteria
- `testPostQuantumProofMustDeriveTheAuthorizer` covers sign-time refusal of a proof for another key, refusal of a non-canonical salt, encode-time refusal of a hand-built envelope, and acceptance of the same proof once `sgnr` names the derived address.
- `testPostQuantumSizesAreEnforced`, `testRekeyedPostQuantumSignerCarriesSgnr`, and `testAuthorizationErrorsDescribeThemselves` pass.
- No `AlgorandError` case is added; `TransactionAuthorizationError` is the only new error type.

