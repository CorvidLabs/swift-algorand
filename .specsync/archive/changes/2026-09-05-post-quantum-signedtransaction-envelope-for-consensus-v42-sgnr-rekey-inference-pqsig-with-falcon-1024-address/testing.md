---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: testing
---

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
