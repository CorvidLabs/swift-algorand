---
change: post-quantum-signedtransaction-envelope-for-consensus-v42-sgnr-rekey-inference-pqsig-with-falcon-1024-address
artifact: context
---

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
