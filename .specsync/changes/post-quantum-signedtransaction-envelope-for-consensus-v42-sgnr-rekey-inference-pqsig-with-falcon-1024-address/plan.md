---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: plan
---

# Plan

## Shape of the change

One modified source file, seven new source files, one modified test file, one new test suite.

| File | Role |
|---|---|
| `Sources/Algorand/SignedTransaction.swift` (modified, superseded from the canonical-encoding change) | Carries a `TransactionAuthorization` and an optional `authAddr`; one internal throwing initializer assembles every signed transaction (mismatch check, `sgnr` inference, proof check); `encode()` builds the envelope through `MessagePackWriter` and splices `txn` last |
| `Sources/Algorand/TransactionAuthorization.swift` | `enum TransactionAuthorization { ed25519, postQuantum }`, its internal `validate(authorizer:)`, and `TransactionAuthorizationError` |
| `Sources/Algorand/TransactionSigner.swift` | The `TransactionSigner` protocol, its `sign(_:groupID:authAddr:)` extension, `Account: TransactionSigner`, and `PQSigner` |
| `Sources/Algorand/Transaction+Signing.swift` | `Transaction.bytesToSign(groupID:)` |
| `Sources/Algorand/PQScheme.swift` | The two-byte tag, `.falcon1024 = "f1"`, internal size tables |
| `Sources/Algorand/PQSignature.swift` | The `pqsig` proof, its internal derived address, shape check, and MessagePack map |
| `Sources/Algorand/Address+PostQuantum.swift` | `SHA512_256("PQA" || sch || slt || pk)` and the ascending canonical-salt scan |
| `Sources/Algorand/Edwards25519.swift` (internal) | GF(2^255-19) arithmetic and the `SetBytes` point predicate |

## Steps, in the order they were taken

1. Create the SpecSync workspace at the accepted base (`95474e8`, with `--path specs/algorand`)
   and, while still a draft, declare five supersessions from the archived canonical-encoding
   change's acceptance manifest: `Sources/Algorand/SignedTransaction.swift` (`b5223f84…`),
   `specs/algorand/algorand.spec.md` (`8fe1bd38…`), `requirements.md` (`071d1889…`),
   `testing.md` (`adbb4bab…`), and `context.md` (`c52ddf4b…`).
2. Read go-algorand v5.0.1-stable (`protocol/pq_scheme.go`, `data/transactions/pqsig.go`,
   `data/basics/pq_address.go`, `crypto/curve25519.go`, `data/transactions/signedtxn.go`,
   `data/transactions/verify/txn.go`, `config/consensus.go`) and pin the facts the code depends
   on: `sch = "f1"` as `[2]byte`, `slt` omitempty, `sgnr == sender` rejected, `PQA` prefix,
   `SetBytes` predicate, `PQSchemeFeeContribution(f1) = 2e6`.
3. Write the seven new files and rewrite `SignedTransaction.swift`; keep the Ed25519 path's bytes
   identical by routing `sig` through the same writer and appending `txn` last.
4. Add `SignedTransactionEnvelopeTests`, `PostQuantumVectorTests` and the `PostQuantumVectors`
   fixtures (throwing calls hoisted out of `#expect`, which the Swift 6.0 macro on Linux does not
   accept inside its expression); leave `CanonicalEncodingTests` untouched — it is an exact-only
   input of the canonical change.
5. Verify: `fledge lanes run verify`; macOS XCTest unchanged at 98 / 20 skipped / 0 failures;
   Swift Testing 57 → 76 with 0 issues; Linux `swift:6.0-jammy` build plus three
   `swift test --skip-build --disable-xctest` runs; byte identity of six envelopes against a build
   of the base sources (identical at 93c952a and 95474e8); read-only TestNet `simulate` probes for
   `sgnr`, `pqsig` with `"f1"`, a patched salt, and a 1538-byte `sig`.
6. Spec: add the seven files to the frontmatter by hand, generate the delta from the live spec so
   the `Public API` body is verbatim plus 17 rows, extend the spec's test plan and design
   decisions, write the artifacts, answer the interview, approve, `check`, commit, `review`,
   `finalize` (patched SpecSync build #753), commit the archive tip, attest, push, draft PR.

## Risks weighed

- Inference changes the bytes emitted when a caller signs with the wrong account: previously a
  `{sig, txn}` envelope the node rejected at signature verification, now a `{sgnr, sig, txn}`
  envelope the node rejects at authorization. Both fail; the new failure names the actual signer.
- The envelope assembler rewrites a one-byte fixmap header. The count is at most three, so the
  header is always one byte; the code guards the writer's header and the key ordering and throws
  `AlgorandError.encodingError` rather than assuming.
- The scheme tag is open (`PQScheme(bytes:)`). A caller can build an envelope for a scheme the
  network does not know; the node answers `pq signature scheme not supported`, which is the
  correct outcome for that input.
