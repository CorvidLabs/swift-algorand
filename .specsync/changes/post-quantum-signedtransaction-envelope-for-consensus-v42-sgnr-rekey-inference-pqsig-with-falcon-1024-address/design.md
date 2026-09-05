---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: design
---

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
