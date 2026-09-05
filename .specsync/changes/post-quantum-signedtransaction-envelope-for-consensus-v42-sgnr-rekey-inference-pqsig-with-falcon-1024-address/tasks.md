---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: tasks
---

# Tasks

- [x] T1 Create the workspace at base `95474e8` with `--path specs/algorand`, and while still a draft supersede `Sources/Algorand/SignedTransaction.swift` (`b5223f84fa0e116de4b364f877948f277cab91b29050d38362d2fcfbe70f501a`), `specs/algorand/algorand.spec.md` (`8fe1bd38…`), `requirements.md` (`071d1889…`), `testing.md` (`adbb4bab…`), and `context.md` (`c52ddf4b…`) from the archived canonical-encoding change's acceptance manifest.
- [x] T2 Find the `sch` constant in go-algorand v5.0.1-stable (`protocol/pq_scheme.go`: `PQSchemeFalcon1024 = PQScheme{'f', '1'}`, `[2]byte`) and confirm live that it moves the node past `pq signature scheme not supported`.
- [x] T3 `PQScheme`: two-byte binary tag, `.falcon1024`, internal size tables (1793 / 1538).
- [x] T4 `Edwards25519` (internal): GF(2^255-19) arithmetic and the `Point.SetBytes` predicate; 13 vectors.
- [x] T5 `Address.postQuantum(scheme:salt:publicKey:)` and `Address.postQuantum(scheme:publicKey:)`; 3 golden keys.
- [x] T6 `PQSignature`: proof value, `slt` omitted when zero, internal shape check and derived address.
- [x] T7 `TransactionAuthorization` and `TransactionAuthorizationError`.
- [x] T8 `Transaction.bytesToSign(groupID:)`: `"TX" || msgpack(txn)`, unhashed.
- [x] T9 `TransactionSigner` protocol, `sign(_:groupID:authAddr:)` extension with `sgnr` inference and the `authAddr` guard, `Account` conformance, `PQSigner` with a `@Sendable` callback.
- [x] T10 Rewrite `SignedTransaction`: `authorization`, `authAddr`, one internal assembling initializer, `encode()` through `MessagePackWriter` with `txn` spliced last, `signature` kept as the raw bytes, `sign(_:with:groupID:authAddr:)`.
- [x] T11 Leave `CanonicalEncodingTests` untouched: a test file is an exact-only delivery input of the change that wrote it, so every envelope and post-quantum test lives in this change's own files.
- [x] T12 `PostQuantumVectorTests` (`testEdwards25519PointPredicateMatchesGoSetBytes`, `testPostQuantumAddressDerivationMatchesGoldenVectors`, `testPostQuantumSignedEnvelopeMatchesGoldenVector`) with fixtures in `PostQuantumVectors`.
- [x] T13 Add `SignedTransactionEnvelopeTests` (16 tests) with throwing calls hoisted out of `#expect` for the Swift 6.0 toolchain.
- [x] T14 `fledge lanes run verify` green; `swift build` warning-free after a forced recompile of every new file.
- [x] T15 Linux: `swift:6.0-jammy` `swift build --build-tests`, then 3 × `timeout 150 swift test --skip-build --disable-xctest`, all exit 0 (76 tests each on the final shape).
- [x] T16 Byte identity: six envelopes (three payments, standalone and grouped) identical between a build of 93c952a and this change, IDs included.
- [x] T17 Live, read-only (`GET /v2/transactions/params`, `POST /v2/transactions/simulate` only): `sgnr` decodes and fails authorization as expected; `pqsig` with `"f1"` reaches Falcon verification; a patched salt makes the node print the address the SDK derives; a 1538-byte `sig` encodes as `bin16` and is decoded by the node.
- [x] T18 Record the fee-usage finding (`group-usage: 3000000` for Falcon-1024) in `PQSigner`'s documentation and in this workspace.
- [x] T19 Spec: seven files added to the frontmatter; delta with the full `Public API` body plus 17 rows, updated `Purpose`, `Invariants` 8-9, two behavioural examples, three error rows, inventory paragraph; REQ-algorand-019 to 023.
- [x] T20 README: rekeyed signing, `TransactionSigner`, and a post-quantum section.
- [x] T21 `specsync change finalize`: run with the spec-sync #753 build, whose archive-preflight fix
      this repository validated end-to-end; rc.12 cannot finalize a v2 successor of CHG-0001. Archived.
