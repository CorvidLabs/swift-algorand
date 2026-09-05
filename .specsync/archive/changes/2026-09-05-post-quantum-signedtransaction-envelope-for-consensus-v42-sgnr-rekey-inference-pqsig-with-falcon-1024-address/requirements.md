---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: requirements
---

# Requirements

The canonical text lives in `deltas/algorand.md` (REQ-algorand-019 through REQ-algorand-023).
This artifact records what each requirement is for and what it deliberately does not ask.

## REQ-algorand-019: the envelope is go-algorand's omit-empty `SignedTxn` map

The envelope must be a canonical map over `lsig < msig < pqsig < sgnr < sig < txn` with only present
keys written and binary headers chosen by length, and the Ed25519-only envelope must be
byte-identical to every previous release's. The identity requirement is what keeps this change
from being a regression for the transactions that work today; the header requirement is what
removes the 255-byte trap.

Not asked: modelling `msig` or `lsig`. They are not produced by this SDK and no vector needs them.

## REQ-algorand-020: `sgnr` is inferred, `authAddr` is a guard

The signer's address is the authorizer; the envelope carries it as `sgnr` exactly when it is not
the sender. An explicit `authAddr` is documentation plus a check, never an override, because a
mismatch between a supplied `authAddr` and the key that actually signs can only be a caller error.

Not asked: inferring anything from on-chain state. Whether the sender really is rekeyed to the
signer is the ledger's decision; the SDK cannot know it offline.

## REQ-algorand-021: post-quantum address derivation

`SHA512_256("PQA" || scheme || salt || publicKey)` with the canonical salt chosen by ascending
rejection sampling against `edwards25519.Point.SetBytes`. Both halves of the predicate
(non-canonical encodings accepted, no subgroup check) are consensus-relevant and pinned by the
13 point-decode vectors; the derivation as a whole is pinned by three golden keys and by the
node's own `derived …` message for a patched salt.

## REQ-algorand-022: the `pqsig` wire shape, the preimage, and the signer seam

`{pk, sch, sig, slt}` with `sch = "f1"` as a two-byte binary and `slt` omitted when zero; the
preimage `"TX" || msgpack(txn)` unhashed through `Transaction.bytesToSign(groupID:)`; signing
delegated through `TransactionSigner`, with `Account` conforming and `PQSigner` wrapping a
caller-supplied callback. No bundled Falcon.

Not asked: verifying a Falcon signature locally, generating Falcon keys, or the fee model. A
Falcon-1024 proof costs two extra minimum fees on v42 (`group-usage: 3000000`); documenting that is
in scope, deriving the fee is the fee-model change.

## REQ-algorand-023: a proof must authorize the transaction

Sizes the decoder enforces and the derived-address check the node makes are made locally, at sign
time and again at encode time, with typed errors. This is the reviewer's defect from the earlier
design, closed on the live path rather than in a helper nobody calls.

Not asked: validating Ed25519 signature bytes. They are carried verbatim, as before.

## Public surface added (17 bare names, 7 declarations of note)

| Symbol | Kind | Why it must be public |
|---|---|---|
| `PQScheme`, `.falcon1024` | struct, constant | The `sch` tag; open so a future scheme can be carried without a release |
| `PQSignature` (`scheme`, `salt`) | struct | The `pqsig` proof a signer returns and an envelope carries |
| `TransactionAuthorization` (`.ed25519`, `.postQuantum`) | enum | What a signed transaction carries; what a signer returns |
| `TransactionAuthorizationError` (`.authAddrMismatch`, `.unauthorizedProof`, `.malformed`) | enum | The typed failures the maintainer asked for, without touching `AlgorandError` |
| `TransactionSigner` (`authorize`) | protocol | The callback seam; `Account` conforms for free |
| `PQSigner` | struct | The post-quantum signer: derives salt and address, wraps the callback |
| `Transaction.bytesToSign(groupID:)` | method | The unhashed preimage for external signers |
| `Address.postQuantum(...)` | 2 static methods | Address derivation with and without the canonical-salt scan |
| `SignedTransaction.authorization` | property | The carried proof; `signature` stays and returns its raw bytes |

Everything else new is `internal`: `Edwards25519`, the scheme size tables, the envelope assembly.
