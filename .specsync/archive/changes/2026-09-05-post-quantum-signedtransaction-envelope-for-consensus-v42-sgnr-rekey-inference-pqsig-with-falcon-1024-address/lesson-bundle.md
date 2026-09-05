# Lesson bundle — post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address

Material for folding this change's lessons into the affected specs' `context.md`.
Synthesise from what actually happened below; do not restate the change description.

## What this change was

- **Title**: Post-quantum SignedTransaction envelope for consensus v42: sgnr rekey inference, pqsig with Falcon-1024 address derivation, a callback TransactionSigner, and bin16 signatures
- **Kind**: Feature
- **Specs**: algorand
- **Paths**: Sources/Algorand, Tests/AlgorandTests, specs/algorand
- **Acceptance**: An Ed25519-only SignedTransaction encodes byte-identically to the previous encoder across six envelope vectors (three payments, standalone and grouped). Signing with an account whose address is not the sender emits sgnr automatically; an explicit authAddr that does not equal the signer throws TransactionAuthorizationError.authAddrMismatch. A pqsig envelope carries sch/slt/pk/sig with sch = f1 and, on a live consensus v42 TestNet node via read-only simulate, reaches Falcon signature verification instead of 'scheme not supported'; Address.postQuantum derives the same address the node derives for the same key and salt; a PQ proof that does not derive the authorizing address throws unauthorizedProof; a 1538-byte signature encodes as bin16 without trapping. Swift Testing grows from 57 to 76 tests in four suites with 0 issues on macOS and Linux swift:6.0-jammy, without editing the canonical change's test file; XCTest remains 98 / 20 skipped / 0 failures; the build is warning-free; no public signature is source-breaking.

## Evidence

- Verification commit: `2bdebe408341d0e5553f6d817cf5a01578cd9540`
- Base commit: `5d081e67f076220c6c00f253bb1e67c552af49a8`
- Verified by: `specsync check --spec algorand`

## From the change's context.md

# Context

## What led here

Consensus v42 (go-algorand v5.0.1-stable, live on MainNet and TestNet, spec hash
`268b63433a907455d439995bf916f6b296018f4f`) added native Falcon-1024 account signatures as a
fourth `SignedTxn` field, `pqsig`. The canonical-encoding change that preceded this one fixed the
transaction preimage but left the signed-transaction envelope as it was: `SignedTransaction.encode()`
hand-wrote a literal `0x82`, `"sig"`, `0xC4`, `UInt8(signature.count)`, `"txn"`. That encoder had
three defects, recorded as vectors by the canonical-encoding change and made live by this one:

- it could not express `sgnr`, so a rekeyed account could not be spent at all;
- it could not express `pqsig`;
- `UInt8(signature.count)` **trapped the process** for any signature over 255 bytes, which is every
  Falcon-1024 signature (1538 bytes constant-time, 1423 compressed maximum).

## Decisions taken before this session (maintainer, final)

- `sgnr` is **inferred**: emitted when the signer's address differs from `transaction.sender`,
  omitted otherwise. That matches py-algorand-sdk and js-algorand-sdk, and consensus rejects a
  `sgnr` equal to the sender (`errAuthAddrEqualsSender`, `EnforceAuthAddrSenderDiff` in
  `data/transactions/verify/txn.go`). An explicit `authAddr` is accepted only as a guard and must
  equal the signer's address.
- One tight change: envelope rewrite + `sgnr` + the >255-byte trap fix + post-quantum address
  derivation + `PQSignature` / `PQScheme` + a callback `TransactionSigner` protocol +
  `Transaction.bytesToSign`. A budget of roughly ten public additions, each justified.
- No Falcon implementation is bundled, matching the official SDKs. Signing is delegated through a
  callback.
- A post-quantum proof must be checked to authorize the transaction at sign time (a defect the
  reviewer found in the earlier design, which had a dead `validated()` path nobody called).

## What this session established

- **The `sch` tag is `"f1"`**: `protocol.PQSchemeFalcon1024 = PQScheme{'f', '1'}` in
  `protocol/pq_scheme.go` at v5.0.1-stable; `PQScheme` is `[2]byte`, so it marshals as a two-byte
  MessagePack binary. The earlier probes tried numeric tags and uppercase `"F1"`/`"FN"` and never
  lowercase `"f1"` as a binary, which is why every probe answered `pq signature scheme not
  supported`. Confirmed live: with `sch = "f1"` the node's answer becomes
  `pq signature validation failed: invalid falcon-1024 signature: error code -4: falcon verify failed`.
- **Address derivation matches the node exactly.** Patching a `pqsig` envelope's `slt` from 0 to 1
  makes TestNet answer `pq signature authorizer mismatch: derived 26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA, expected VPLOXBX3KMMRW45C4ANLKSBVJU7UUMFRLRVIPDMZMVOMA5FAU7IB3YRGJI`,
  and `Address.postQuantum(scheme: .falcon1024, salt: 1, publicKey:)` produces that same
  `26KVNLGM…` address. The point predicate is `filippo.io/edwards25519`'s `Point.SetBytes`
  (non-canonical encodings accepted, no subgroup check); `crypto.IsEdwards25519Point` and
  `basics.CanonicalPQAddressSalt` in go-algorand were read directly.
- **A Falcon-1024 proof is not free.** The ground truth said a PQ signature adds zero fee usage;
  that measurement was taken with an unsupported scheme tag, for which
  `SignedTxn.signatureFeeContribution` deliberately returns zero. With `sch = "f1"` the same
  payment reports `group-usage: 3000000` against `1000000` for Ed25519, exactly
  `PQSchemeFeeContribution(f1) = 2e6` in `config/consensus.go`. The live check wins. The SDK does
  not derive fees from the signature type (the fee-model change is separate); the `PQSigner`
  documentation says so and tells callers to set the fee.
- **A pre-written placeholder could never have passed as written.** The canonical change's
  oversized-signature placeholder asserted that no `0xC4` byte appears anywhere in the envelope,
  but the transaction's own 32-byte `gh`, `rcv`, and `snd` fields legitimately carry `c4 20`.
  That placeholder is gone; this change's suite checks the `sig` header positionally
  (`82a3736967c50602`).
- **`testSignedEnvelopeStructure` signed with a random account.** Under inference that is a rekeyed
  signer and the envelope correctly grows a `sgnr` key; the test now signs with the sender.

## Things ruled out

- The earlier 65-symbol design (`Ed25519TransactionSigner`, `PostQuantumTransactionSigner`, a
  struct-with-`Kind` authorization type, `Edwards25519` public, `feeContributionMicros`,
  `validated()`, `transactionID(groupID:)`, a `MessagePackWriter.write(map:preEncoded:)` overload).
  Cut to 17 new bare names in 7 new files, one modified source file, no `MessagePackWriter` change.
- Validating Ed25519 signature length at encode time. The gated oversized-signature test feeds a
  1538-byte value through the Ed25519 slot on purpose; the bytes are carried verbatim as before.
- Adding cases to `AlgorandError` (source-breaking for exhaustive switches). A new
  `TransactionAuthorizationError` carries the three typed failures instead.
- Superseding test files: they are delivery evidence (`@exact:test`), not module obligations.
  This change supersedes the one pre-existing source file it modifies
  (`Sources/Algorand/SignedTransaction.swift`) and the four `specs/algorand` companions the
  canonical-encoding change delivered (`algorand.spec.md`, `requirements.md`, `testing.md`,
  `context.md`), each from that change's archived acceptance manifest, against base `95474e8`.

## Licence boundary

No vector was copied from `algorandfoundation/falcon-signatures` (AGPL-3.0) or
`algorandfoundation/algokit-polytest` (unlicensed). The post-quantum public keys are deterministic
1793-byte stand-ins and the signature is a 1538-byte stand-in; they exercise derivation, envelope
shape, and the node's scheme and authorizer checks, and they fail Falcon verification by design.

## Supersession lesson

Supersede exactly the pre-existing files the change modifies — no more, no fewer. A missing edge
surfaces at `finalize` as the predecessor being rejected for stale evidence; an extra edge is
refused at `finalize` because the obligation "does not change the predecessor entry". Test files
cannot be superseded at all (`@exact:test` inputs of the change that wrote them), so a change never
edits a predecessor's test file and adds its own suites instead. Supersession is draft-only, so
getting the set wrong means recreating the workspace.

## From the change's design.md

# Design

## Authorization as a value, not a fixed map

`SignedTransaction` gains a `TransactionAuthorization` enum — `.ed25519(Data)` and
`.postQuantum(PQSignature)` — and its encoder builds the envelope through `MessagePackWriter`
instead of hand-emitting a two-key `{sig, txn}` map. Keys are written in canonical order
(`lsig` < `msig` < `pqsig` < `sgnr` < `sig` < `txn`) and only when present, so an Ed25519-only
envelope is byte-identical to the previous encoder (proven against a build of the parent commit
for six envelopes) and the multisig/logic-signature cases can be added later as further enum
cases without a wire change. The bin8 header and `UInt8(signature.count)` trap are gone;
`MessagePackWriter` selects bin8/bin16/bin32 itself. `signature` stays a computed `Data` — the raw
bytes of either scheme — so no existing call site breaks.

## Rekeyed accounts: `sgnr`

`SignedTransaction.sign(_:with:groupID:authAddr:)` emits `sgnr` = the signer's address whenever
that address differs from `transaction.sender`. The optional `authAddr` documents intent and is
checked: a value that is not the signer's address throws
`TransactionAuthorizationError.authAddrMismatch`. This is the policy of py- and js-algorand-sdk.

## Post-quantum accounts

- `PQScheme` (`.falcon1024`, wire tag `"f1"`, public-key and signature size bounds).
- `PQSignature` (`scheme`, `salt`, `publicKey`, `signature`) — validated when a transaction is
  signed with it: the key, scheme and salt must derive the authorizing address, otherwise
  `.unauthorizedProof`; malformed sizes throw `.malformed`.
- `Address.postQuantum(scheme:salt:publicKey:)` and `Address.postQuantum(scheme:publicKey:)`,
  the latter scanning for the canonical salt with the internal `Edwards25519` point check that
  mirrors Go's `SetBytes` semantics.
- `TransactionSigner` — `address` plus an `authorize` callback producing a
  `TransactionAuthorization` for the exact `bytesToSign` preimage; `Account` conforms.
  `PQSigner` wraps a caller-supplied Falcon backend and carries the scheme, salt and public key.
- `Transaction.bytesToSign(groupID:)` — `"TX" || msgpack(txn)`, unhashed.

## Public surface

Seventeen new public bare names: `PQScheme`, `falcon1024`, `PQSignature`, `scheme`, `salt`,
`TransactionAuthorization`, `ed25519`, `postQuantum`, `TransactionAuthorizationError`,
`authAddrMismatch`, `unauthorizedProof`, `malformed`, `TransactionSigner`, `authorize`,
`PQSigner`, `bytesToSign`, `authorization`. `Edwards25519` is internal. No source-breaking change.

## Out of scope, deliberately

The v42 fee model (including the 2e6 usage a Falcon envelope costs), multisig and logic-signature
envelopes, and any bundled Falcon implementation. Each is additive on top of this enum.

## From the change's testing.md

# Testing

## The suites

Two Swift Testing suites carry this change; XCTest is untouched.

`Tests/AlgorandTests/CanonicalEncodingTests.swift` is untouched: a test file is an exact-only
delivery input of the change that wrote it. Everything this change proves lives in its own files:

| File | Contents |
|---|---|
| `SignedTransactionEnvelopeTests.swift` | 16 tests: byte identity of Ed25519 envelopes (standalone and grouped), `sgnr` inference and the `authAddr` guard, the `TransactionSigner` path, `bytesToSign`, post-quantum salt and address derivation, proof validation, size enforcement and the positional `sig` header, the `"f1"` scheme tag, and error descriptions |
| `PostQuantumVectorTests.swift` | [Vectors] `testEdwards25519PointPredicateMatchesGoSetBytes` (13 point-decode cases), [Vectors] `testPostQuantumAddressDerivationMatchesGoldenVectors`, [Vectors] `testPostQuantumSignedEnvelopeMatchesGoldenVector` (the 3530-byte `pq_signed_payment` envelope) |
| `PostQuantumVectors.swift` | the fixtures those suites read: point cases, address vectors, Falcon sizes, the scheme tag, the signature and signed-payment vectors, and the rekeyed-`sgnr` envelope vector |

`Tests/AlgorandTests/SignedTransactionEnvelopeTests.swift` — 14 new tests around the vectors:
byte identity with a hand-written legacy `{sig, txn}` layout and with `signed_ed25519_only`
(standalone and grouped); `signature` for both kinds; `sgnr` omitted for the sender and inferred
for the auth account (`signed_ed25519_rekeyed_sgnr`, byte-exact where Ed25519 is deterministic);
the explicit-`authAddr` guard on both signing paths; `Account` through the protocol path; a custom
signer receiving the exact preimage; `bytesToSign`; `PQSigner` salt and address per key; `slt`
present only when non-zero and after `sig`; a post-quantum signer acting for a rekeyed Ed25519
sender; proof-must-derive-the-authorizer at sign time and encode time; size enforcement; the
`"f1"` tag; error descriptions. Every throwing call is hoisted out of `#expect` because the Swift
6.0 toolchain's macro rejects `try` inside its expression (found on Linux, not on the newer macOS
toolchain).

## Results

| Platform | XCTest | Swift Testing |
|---|---|---|
| macOS, `fledge lanes run verify` (`swift build` + `CI=true swift test`) | 98 executed, 20 skipped, 0 failures (unchanged from 93c952a) | 76 tests in 4 suites, 0 issues, 1 skipped (was 57 tests, 1 skipped) |
| Linux, `swift:6.0-jammy`, `swift build --build-tests` then 3 × `timeout 150 swift test --skip-build --disable-xctest` | not run (XCTest hangs on Linux, swift-corelibs-xctest #504) | 76 tests passed, exit 0, three runs out of three |

The one remaining skip is the Darwin-only byte-exact Ed25519 envelope test — CryptoKit randomises
the nonce — which runs and passes on Linux.

`swift build` is warning-free after `touch`ing every new source file so the module recompiles in
full.

## Byte identity against 93c952a

Two scratch executables, one depending on a copy of the tree at 93c952a and one on this change,
encoded the same three payments (plain; with note and lease; with `rekeyTo` and
`closeRemainderTo`) under a fixed 64-byte signature, standalone and under a group ID. All six
envelopes and all six transaction IDs are identical (`cmp` of the two outputs: no difference;
241 / 279 / 301 / 339 / 312 / 350 bytes).

## Live verification (read-only)

`GET https://testnet-api.algonode.cloud/v2/transactions/params` for the current round, then
`POST /v2/transactions/simulate` with `Content-Type: application/msgpack` and the body
`{"txn-groups":[{"txns":[<signed txn>]}]}`. `POST /v2/transactions` was never called; the accounts
are unfunded throwaways. Consensus reported: `https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f`.

| Probe | Node response |
|---|---|
| Ed25519 signer ≠ sender (`sgnr` inferred) | HTTP 200, `failure-message: transaction O3BH…: should have been authorized by CMQF…JBBM but was actually authorized by KG44…HJDU`, `group-usage: 1000000`. The envelope decoded and `sgnr` was read; the failure is authorization, because the throwaway sender is not rekeyed on chain. |
| Control: sender signs for itself | HTTP 200, `failure-message: … overspend (account CMQF…)`, i.e. past signature verification. |
| `pqsig` with `sch = "f1"`, sender = derived PQ address (salt 0) | HTTP 200, `… invalid : pq signature validation failed: invalid falcon-1024 signature: error code -4: falcon verify failed`, `group-usage: 3000000`. Past the scheme check (every other tag answered `pq signature scheme not supported`) and past the authorizer check; the stand-in signature fails Falcon verification as expected. |
| Same proof, PQ signer acting for an Ed25519 sender (`pqsig` + `sgnr`) | HTTP 200, the same `falcon verify failed`, `group-usage: 3000000`. |
| Same envelope with `slt` patched to 1 (the SDK refuses to build this) | HTTP 200, `… pq signature authorizer mismatch: derived 26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA, expected VPLOXBX3KMMRW45C4ANLKSBVJU7UUMFRLRVIPDMZMVOMA5FAU7IB3YRGJI`. The SDK's `Address.postQuantum(scheme: .falcon1024, salt: 1, publicKey:)` for the same key is `26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA`. |
| 1538-byte value in the Ed25519 `sig` slot | Envelope header `82a3736967c50602`, 1713 bytes, no trap. HTTP 400 `{"message":"At least one signature didn't pass verification"}`: the node decoded the `bin16` value and failed signature verification rather than decoding. |

The `group-usage: 3000000` figure contradicts the ground-truth claim that a PQ signature adds no
fee usage; that claim was measured with an unsupported scheme tag, which contributes zero by
design. The live check wins and is recorded in `PQSigner`'s documentation.

## Requirement evidence

Tests are in `Tests/AlgorandTests/SignedTransactionEnvelopeTests.swift` unless marked `[Vectors]`
(`PostQuantumVectorTests.swift`); the canonical suite is untouched by this change.

| Requirement | Evidence |
|---|---|
| REQ-algorand-019 | `[Vectors]` `testEd25519EnvelopeIsByteIdenticalToLegacyEncoder`, `testGroupedEd25519EnvelopeIsByteIdenticalToLegacyEncoder`, `testSignatureAccessorReturnsRawBytesForBothSchemes`; `testPostQuantumSizesAreEnforced`, `testSignedEnvelopeStructure`, `testSignedEnvelopeIsByteExactOnDeterministicBackends`; the six-envelope diff against 93c952a; live: the `bin16` `sig` decoded by the node. |
| REQ-algorand-020 | `testSignerDifferentFromSenderInfersSgnr`, `testRekeyedPostQuantumSignerCarriesSgnr`; `[Vectors]` `testSignerEqualToSenderOmitsSgnr`, `testSignerDifferentFromSenderInfersSgnr`, `testExplicitAuthAddrMustNameTheSigner`, `testAccountSignsThroughTheProtocolPath`, `testCustomSignerReceivesThePreimageAndControlsSgnr`; live: `should have been authorized by … but was actually authorized by …`. |
| REQ-algorand-021 | [Vectors] `testEdwards25519PointPredicateMatchesGoSetBytes`, [Vectors] `testPostQuantumAddressDerivationMatchesGoldenVectors`; `[Vectors]` `testPostQuantumSignerDerivesCanonicalSaltAndAddress`; live: the node's `derived 26KVNLGM…` equals the SDK's salt-1 derivation. |
| REQ-algorand-022 | [Vectors] `testPostQuantumSignedEnvelopeMatchesGoldenVector`; `[Vectors]` `testPostQuantumSaltIsOmittedWhenZeroAndPresentOtherwise`, `testCustomSignerReceivesThePreimageAndControlsSgnr`, `testBytesToSignIsThePrefixedCanonicalEncoding`, `testPostQuantumSchemeTag`; live: `sch = "f1"` reaches `falcon verify failed`. |
| REQ-algorand-023 | `[Vectors]` `testPostQuantumProofMustDeriveTheAuthorizer`, `testPostQuantumSizesAreEnforced`, `testRekeyedPostQuantumSignerCarriesSgnr`, `testAuthorizationErrorsDescribeThemselves`. |

## Where these lessons go

- `specs/algorand/context.md`
