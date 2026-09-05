---
id: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
state: implementing
type: feature
base_commit: 5d081e67f076220c6c00f253bb1e67c552af49a8
---

# Post-quantum SignedTransaction envelope for consensus v42: sgnr rekey inference, pqsig with Falcon-1024 address derivation, a callback TransactionSigner, and bin16 signatures

## Intent

Post-quantum SignedTransaction envelope for consensus v42: sgnr rekey inference, pqsig with Falcon-1024 address derivation, a callback TransactionSigner, and bin16 signatures

## Affected Canonical Specs

- `algorand`

## Acceptance Criteria

- An Ed25519-only SignedTransaction encodes byte-identically to the previous encoder across six envelope vectors (three payments, standalone and grouped). Signing with an account whose address is not the sender emits sgnr automatically; an explicit authAddr that does not equal the signer throws TransactionAuthorizationError.authAddrMismatch. A pqsig envelope carries sch/slt/pk/sig with sch = f1 and, on a live consensus v42 TestNet node via read-only simulate, reaches Falcon signature verification instead of 'scheme not supported'; Address.postQuantum derives the same address the node derives for the same key and salt; a PQ proof that does not derive the authorizing address throws unauthorizedProof; a 1538-byte signature encodes as bin16 without trapping. Swift Testing grows from 57 to 76 tests in four suites with 0 issues on macOS and Linux swift:6.0-jammy, without editing the canonical change's test file; XCTest remains 98 / 20 skipped / 0 failures; the build is warning-free; no public signature is source-breaking.

## No-spec Rationale

Not applicable
