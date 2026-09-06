---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: research
---

# Research

## Consensus v42 and the wire shape

go-algorand v5.0.1-stable (consensus v42, live on MainNet and TestNet) adds native Falcon-1024
account signatures as a fourth `SignedTxn` field, `pqsig`. Its shape was recovered from the node's
strict decoder, which rejects unknown keys as a hard decode error: `pqsig: {sch: [2]byte,
slt: uint8, pk: bytes, sig: bytes}`, with `sgnr` accepted at the envelope's top level. The scheme
discriminant is `"f1"` — `protocol.PQSchemeFalcon1024 = PQScheme{'f', '1'}`, `type PQScheme [2]byte`
(`protocol/pq_scheme.go`; `crypto/pq_scheme.go` `LookupPQScheme`). Earlier probes tried only
numeric tags and upper-case letters, which is why the discriminant looked unrecoverable. Falcon
det1024 sizes: public key 1793 bytes, signature 1538 (constant-time) or up to 1423 (compressed);
`MessagePackWriter` emits bin16 for both.

## Address derivation

A post-quantum address is `SHA512_256("PQA" || scheme || salt || publicKey)`. The canonical salt is
the first value in 0...255 whose resulting 32 bytes are NOT a valid edwards25519 point, so a PQ
address can never collide with an Ed25519 public key. The point check must match Go's
`edwards25519.Point.SetBytes` exactly: non-canonical encodings are accepted and prime-order
subgroup membership is not required. Verified live: with `slt` patched to 1 the node reported
the derived address `26KVNLGM25G46YMGMOVXRKGLUGOWUEYIMNLZEIVO2KFOCCXUCVNRIYBCNA`, identical to the
SDK's salt-1 derivation.

## What the node accepts (read-only `/v2/transactions/simulate`, TestNet v42)

- Envelope carrying `sgnr`: HTTP 200, `should have been authorized by CMQF…JBBM but was actually
  authorized by KG44…HJDU` — decoded and evaluated; the failure is authorization, because the
  throwaway sender is not rekeyed on chain. Control payment: `overspend`.
- `pqsig` with `"f1"`: `pq signature validation failed: invalid falcon-1024 signature: error code
  -4: falcon verify failed` — past the scheme and authorizer checks, into Falcon verification.
- 1538-byte `sig`: header `82a3736967c50602` (bin16, no trap); HTTP 400 signature failure rather
  than a decode error.
- Fee usage: `group-usage 3000000` for the Falcon envelope versus `1000000` for Ed25519, i.e.
  `PQSchemeFeeContribution(f1) = 2e6`. An earlier measurement of zero was taken with an
  unsupported scheme tag and is withdrawn; the fee model must charge it.

## Signing model

The signing preimage is `"TX" || msgpack(txn)`, unhashed; it is exposed as
`Transaction.bytesToSign(groupID:)`. None of the official SDKs bundle a Falcon implementation:
py- and js-algorand-sdk derive the address, build the envelope, and delegate the raw signature to
a caller-supplied callback. This change follows that shape with `TransactionSigner`/`PQSigner`.
`sgnr` is inferred when the signer's address is not the sender (py- and js-algorand-sdk do the
same); an explicit `authAddr` must equal the signer or signing throws.

## Defects in the earlier design, and their resolution

The reviewed design shipped two conflicting `sgnr` policies; one policy (infer, explicit must
match) is used everywhere. It also never checked that a PQ proof authorizes the transaction;
`PQSignature` proofs are validated at signing time — the public key, scheme and salt must derive
the authorizing address — and `encode()` throws `TransactionAuthorizationError.unauthorizedProof`
otherwise. It proposed 65 public symbols; 17 bare names ship.

## Test corpus and licensing

Vectors for PQ address derivation, the `pqsig` envelope, 13 edwards25519 point-decode cases and the
rekeyed-`sgnr` envelope were regenerated from first principles; the Algorand Foundation's
`lsig_address_kat.json` and py-algorand-sdk's `pq_test_data/*` are AGPL-3.0 and were not copied.
The canonical suite is untouched — a test file is an exact-only delivery input of the change that
wrote it — so this change carries every envelope and post-quantum test in its own files:
`SignedTransactionEnvelopeTests.swift`, `PostQuantumVectorTests.swift` and the `PostQuantumVectors`
fixtures. The canonical change's oversized-signature placeholder had asserted that no `0xC4` byte
appears anywhere, which every transaction's `gh`/`rcv`/`snd` fields carry, so it could never pass;
this suite checks the `sig` header positionally. On Linux Swift 6.0 the `#expect` macro rejects
`try` inside its expression, so throwing calls are hoisted.
