---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: docs
---

# Docs

## What changed for a caller

- `SignedTransaction.sign(_:with:groupID:)` keeps its signature and gains a defaulted `authAddr:`
  parameter. Signing with an account that is not the sender now emits `sgnr`; before, it emitted a
  `{sig, txn}` envelope the node rejected at signature verification.
- `SignedTransaction.signature` is still there and still returns the raw signature bytes; for a
  post-quantum authorization those are the Falcon bytes. `authorization` is the typed payload.
- `SignedTransaction.encode()` can now throw `TransactionAuthorizationError` for a post-quantum
  proof that does not authorize the sender or `sgnr`. For Ed25519 it throws nothing new.
- `Account` conforms to `TransactionSigner`, so `try await account.sign(transaction)` works.
- New: `PQScheme`, `PQSignature`, `TransactionAuthorization`, `TransactionAuthorizationError`,
  `TransactionSigner`, `PQSigner`, `Transaction.bytesToSign(groupID:)`,
  `Address.postQuantum(scheme:salt:publicKey:)`, `Address.postQuantum(scheme:publicKey:)`,
  `SignedTransaction.authorization`, `SignedTransaction.init(transaction:authorization:authAddr:groupID:)`.

## Source-breaking changes

None found. Every existing signature compiles unchanged: the stored `signature` became a computed
property of the same type, the static `sign` gained only a defaulted parameter, and the Ed25519
convenience initializer is unchanged. `AlgorandError` gained no case. Callers with their own
`Account` extension named `authorize(_:)` would now collide with the protocol requirement; none is
known.

## Where the documentation lives

- Every public symbol carries a doc comment; `PQSigner`, `PQSignature`, `PQScheme`,
  `TransactionSigner`, and `Transaction.bytesToSign` explain the wire facts they depend on (the
  `"f1"` tag as a two-byte binary, `slt` omitted when zero, the unhashed preimage, `sgnr`
  inference and why `sgnr == sender` is rejected, the fee usage a Falcon-1024 proof adds).
- `README.md` "Signing" gained rekeyed signing, the `TransactionSigner` path, and a
  "Post-quantum accounts (consensus v42)" section with the `PQSigner` callback shape.
- The living spec's `Public API`, `Invariants` (8, 9), `Behavioral Examples`, `Error Cases`, and
  inventory sections are updated through the delta; REQ-algorand-019 to 023 are the contract.
- The DocC catalog (`Sources/Algorand/Algorand.docc`) is not modified by this change; its symbol
  pages are generated from the doc comments above.

## Facts worth repeating anywhere the SDK is described

- Falcon-1024 scheme tag: `"f1"`, lowercase, two bytes, MessagePack binary
  (`protocol.PQSchemeFalcon1024` in go-algorand v5.0.1-stable).
- Post-quantum address: `SHA512_256("PQA" || "f1" || salt || publicKey)`, canonical salt = lowest
  in `0...255` whose digest is not an Edwards25519 point under `Point.SetBytes` rules.
- Preimage: `"TX" || msgpack(txn)`, never hashed by the SDK.
- Sizes: public key 1793 bytes, signature at most 1538 bytes (`bin16` headers).
- A Falcon-1024 proof adds two minimum fees of usage on consensus v42 (`group-usage: 3000000`);
  builders still default the fee to the minimum, so set it.
- No Falcon implementation is bundled; the official Python and JavaScript SDKs bundle none either.
