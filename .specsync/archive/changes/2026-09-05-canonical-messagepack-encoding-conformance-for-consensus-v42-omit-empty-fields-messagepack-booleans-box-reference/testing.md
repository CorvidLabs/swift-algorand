---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: testing
---

# Testing

## The suite

Two files.

`Tests/AlgorandTests/CanonicalBoxReferenceTests.swift` exercises the box-index translation in
isolation — the four rules, the `apfa` append path, and the eight-application limit. It exists
because the encoding vectors cannot reach the append path: both box vectors declare `apfa`
explicitly, so the rule that matters most for a caller who forgets to is untested by them.

`Tests/AlgorandTests/CanonicalEncodingTests.swift` — 51 Swift Testing tests over the canonical
encoding vectors (plus 6 in `CanonicalBoxReferenceTests.swift`; both suites are `@Suite` structs;
57 tests, 21 platform-conditional skips). Vectors for behaviour this change does not make
live are recorded in `DeferredVectors.swift` or by name only:

| Group | Count | What it pins |
|---|---|---|
| Transaction encoding vectors | 52 | Full encoded bytes as a hex literal **and** the base32 transaction ID |
| Atomic group ID | 1 | `2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899` for the golden two-payment group |
| Ed25519 point-decode cases | 13 | `edwards25519.Point.SetBytes` acceptance, which determines the canonical PQ-address salt |
| Post-quantum address cases | 3 | `SHA512_256("PQA" + scheme + salt + publicKey)` derivation |

The data lives in `canonical-vectors.json`; `gen_vectors.py` regenerates it. Both belong beside the
suite so a future session can re-derive rather than trust.

**Every assertion is byte equality against a hex literal.** That is the point. The pre-existing
encoding tests assert `encoded.count > 0` or that some substring is present, which cannot
distinguish a correct encoder from a differently-wrong one — which is exactly how the shipped
encoder passed CI while producing transactions the network rejects.

## Vector coverage by transaction family

| Family | Vectors |
|---|---|
| `pay` (13) | `pay_normal`, `pay_fee_zero`, `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`, `pay_empty_genesis_id`, `pay_zero_amount`, `pay_all_omittable_zero`, `pay_close_remainder_to`, `pay_rekey_to`, `pay_full`, `pay_min_fee_from_params`, `pay_large_fee_uint64` |
| `keyreg` (4) | `keyreg_online`, `keyreg_offline`, `keyreg_nonparticipating`, `keyreg_online_no_stateproof` |
| `axfer` (5) | `axfer_opt_in`, `axfer_transfer`, `axfer_close_to`, `axfer_clawback`, `axfer_zero_asset_id` |
| `acfg` (5) | `acfg_create_minimal`, `acfg_create_full`, `acfg_create_default_frozen_false`, `acfg_reconfigure`, `acfg_destroy` |
| `afrz` (2) | `afrz_freeze`, `afrz_unfreeze` |
| `appl` (15) | `appl_noop_minimal`, `appl_opt_in`, `appl_args`, `appl_accounts_assets_apps`, `appl_box_current_app`, `appl_box_self_app_id`, `appl_box_foreign_app`, `appl_box_empty_name`, `appl_create_with_schemas`, `appl_create_zero_schemas`, `appl_create_extra_pages`, `appl_extra_pages_zero`, `appl_delete`, `appl_kitchen_sink`, `appl_access_list_and_reject_version` |
| `hb` / `stpf` (2) | `hb_heartbeat`, `stpf_state_proof` — not modelled by the SDK; skipped |
| groups (3) | `group_txn0_grouped`, `group_txn1_grouped`, `group_txn0_ungrouped` |
| envelopes (3) | `signed_ed25519_only`, `signed_ed25519_rekeyed_sgnr`, `signed_grouped` |

## Baseline: the 15 failures before the change

Identical on macOS and Linux. Thirteen are in scope; two are deferred.

| Vector | Test case | Why it fails today |
|---|---|---|
| `pay_fee_zero` | `testPayFeeZero` | `fee` written when 0 |
| `pay_first_valid_zero` | `testPayFirstValidZero` | `fv` written when 0 |
| `pay_empty_note` | `testPayEmptyNote` | `note` written when empty |
| `pay_zero_lease` | `testPayZeroLease` | `lx` written when all 32 bytes are zero |
| `pay_empty_genesis_id` | `testPayEmptyGenesisId` | `gen` written when `""` |
| `pay_all_omittable_zero` | `testPayAllOmittableZero` | all of the above compounded; correct answer is a 129-byte five-entry map |
| `keyreg_nonparticipating` | `testKeyregNonparticipating` | `nonpart` written as `uint 1` (`0x01`) not `bool` (`0xC3`) |
| `axfer_zero_asset_id` | `testAxferZeroAssetId` | `xaid` written when 0 |
| `appl_box_self_app_id` | `testApplBoxSelfAppId` | box on the called app writes `i` = the raw app ID |
| `appl_box_foreign_app` | `testApplBoxForeignApp` | `i` is the raw app ID, not the 1-based `apfa` index |
| `appl_box_empty_name` | `testApplBoxEmptyName` | `n` written when empty; should leave an empty map |
| `appl_kitchen_sink` | `testApplKitchenSink` | box index translation, compounded with the header rules |
| `group_txn0_grouped` | `testSignedGroupedTransactionReportsGroupedID` | `SignedTransaction.id()` re-encodes with `groupID: nil` and reports an ID that does not exist on chain |
| `pay_min_fee_from_params` | `testBuilderDerivesFeeFromSuggestedParameters` | **deferred** — v42 fee model |
| `signed_ed25519_rekeyed_sgnr` | `testRekeyedEnvelopeCarriesSgnr` | **deferred** — `SignedTransaction` envelope rewrite |

## Deferred vectors

Test files are exact-only delivery inputs of the change that wrote them: a later change cannot
edit this suite without reopening this change. So this suite contains no forward-looking
placeholders. The `pay_min_fee_from_params` vector (fee model) lives in `DeferredVectors.swift`;
the rekeyed-`sgnr` and post-quantum envelope vectors are carried byte-exact by the envelope
change's own suite; `appl_access_list_and_reject_version`, `hb_heartbeat` and `stpf_state_proof`
are recorded by name, their bytes in the generator. Each follow-up change adds its own test file.

## Why Swift Testing, and what Linux proves

The suites were first written for XCTest and hung the Linux process. The cause is an open
lost-wakeup deadlock in swift-corelibs-xctest (#504) that microsecond-fast synchronous tests
trigger almost every run under Docker Desktop on 6.0 and 6.1; research.md has the backtrace and
bisection. Swift Testing has no `XCTWaiter`/run-loop in its path and needs no manifest change.

Linux acceptance for this change is therefore the ported suites in isolation:
`CI=true swift test --disable-xctest` (the `--testing-library` flag is a usage error on 6.0/6.1
SwiftPM) — 5/5 clean runs on swift:6.0-jammy and 5/5 on swift:6.1-jammy with the earlier 65-test
shape of this suite; the restructured 57-test shape is re-verified on Linux before finalize. End-to-end `CI=true swift test` on Linux still hangs locally, 5/5, always inside a
pre-existing XCTest case (`AccountTests`, `AssetManagementTests`, `AtomicTransactionGroupTests`,
`IntegrationTests`, `ProofOfWorkTest` — never a Canonical test). That exposure predates this
change, is byte-for-byte unchanged by it, and has passed GitHub's x86_64 ubuntu job repeatedly;
migrating the legacy suite to Swift Testing is a separate change.

Four vectors named by placeholder tests (`appl_access_list_and_reject_version`, `hb_heartbeat`,
`stpf_state_proof`, and `signed_grouped`'s envelope bytes) have their bytes only in
`canonical-vectors.json`, not yet transcribed into Swift; copy them in when those tests go live.

- **`signed_ed25519_rekeyed_sgnr`.** The correct envelope for a rekeyed account is a three-key map
  `{sgnr, sig, txn}` (280 bytes, opening `83 a473676e72 c420 …`). `SignedTransaction.encode()`
  hand-emits a literal `0x82` two-key map and cannot express it at all. Fixing it means replacing
  the envelope with an authorization enum covering `sig` / `sgnr` / `msig` / `lsig` / `pqsig` —
  which is the post-quantum change, and is separate.
- **`pay_min_fee_from_params`.** The builder's default fee is a hard-coded `1000`, baked into 21
  initializer defaults plus a stored property on `PaymentTransactionBuilder`.
  `TransactionParams.minFee` is decoded from algod and then never read, so a network whose minimum
  fee is not 1000 silently underpays. Fixing it means adopting the v42 fee model (`research.md`
  §10), which is a separate change.

## Pre-existing skips, unchanged by this change

| Test | Reason |
|---|---|
| `testEnvelopeSurvivesSignaturesLongerThan255Bytes` | `SignedTransaction.encode()` emits a hard-coded `bin8` header then `UInt8(signature.count)`. A 1538-byte Falcon-1024 signature **traps the process** rather than throwing, so it cannot be asserted in-process. Belongs to the envelope rewrite |
| `testPostQuantumAddressDerivationIsNotImplemented` | No PQ address derivation in the SDK |
| `testPostQuantumSignedEnvelopeIsNotImplemented` | No `pqsig` envelope in the SDK |
| `testAccessListAndRejectVersionAreNotImplemented` | v42 `al` / `aprv` fields not modelled |
| `testHeartbeatTransactionIsNotImplemented` | No `hb` transaction type |
| `testStateProofTransactionIsNotImplemented` | No `stpf` transaction type |
| `testSignedEnvelopeIsByteExactOnDeterministicBackends` | **macOS only.** CryptoKit randomizes the Ed25519 nonce, so raw signature bytes are not reproducible on Darwin. Runs and passes on Linux, where swift-crypto's Ed25519 is deterministic — this is the entire macOS/Linux count difference |

## Results

| Platform | Before | After (target) |
|---|---|---|
| macOS (`swift test`) | 36 pass / 15 fail / 7 skip | 49 pass / 0 fail / 9 skip |
| Linux (Docker `swift:6.0-jammy`) | 37 pass / 15 fail / 6 skip | 50 pass / 0 fail / 8 skip |

58 cases on both platforms. The failing set is identical on both — this is an encoding defect, not a
platform defect.

## Independent verification: the live node

The vectors say the SDK agrees with a reimplementation of go-algorand's marshaller. Only the network
can say the SDK agrees with go-algorand. For each of the 13 fixed vectors, the new bytes go to
`POST https://testnet-api.algonode.cloud/v2/transactions/simulate`:

- **Pass criterion:** `HTTP 200` and execution reaches balance application — for an unfunded
  throwaway sender that surfaces as `failure-message: "transaction …: overspend (account …)"`, which
  is *past* signature verification.
- **The control it replaces:** the same transaction built by the pre-change encoder returns
  `HTTP 400 {"message":"At least one signature didn't pass verification"}`.
- **Box vectors additionally:** `HTTP 200` with **no** `failure-message`, where the pre-change form
  returns `HTTP 200` carrying `tx.Boxes[0].Index is <N>. Exceeds len(tx.ForeignApps)`. A status-code
  check alone would miss this, so the assertion must read `failure-message`.

Constraints on this lane: `GET` and `POST /v2/transactions/simulate` only. `POST /v2/transactions`
is never called, no funds move, nothing lands on chain. It runs outside the deterministic
pull-request lane, consistent with existing invariant 5 in the canonical spec.

## Regression fence

The 37 vectors passing before the change must pass after it, byte-identical. They are the
transactions that carry no zero or empty field — the shape of every working transaction in
production. A regression there breaks transactions that work today, which is strictly worse than
the bug being fixed.

## Requirement evidence

All tests below live in `Tests/AlgorandTests/CanonicalEncodingTests.swift` unless marked `[Box]`
(`Tests/AlgorandTests/CanonicalBoxReferenceTests.swift`). Every listed test asserts byte equality
against a go-algorand-derived golden vector or a live-node-confirmed behaviour.

| Requirement | Evidence |
|---|---|
| REQ-algorand-002 | `testPayNormal`, `testPayFull`, `testKeyregOnline`, `testAxferTransfer`, `testAcfgCreateFull`, `testAfrzFreeze`, `testApplKitchenSink` — byte-exact encodings and transaction IDs; the 69-vector suite as a whole. Live: fee=0 / empty note / zero lease / empty gen payment reaches `overspend` (signature verified) on TestNet v42. |
| REQ-algorand-006 | `testApplBoxCurrentApp`, `testApplBoxSelfAppId`, `testApplBoxForeignApp`, `testApplBoxAppendPath`, `testApplBoxEmptyName`, `testApplKitchenSink`, `testApplAccountsAssetsApps` — boxes named by owning application ID encode as `apfa` slot indexes. |
| REQ-algorand-007 | `testKeyregNonparticipating` (`nonpart` = `0xC3`), `testKeyregOffline` (`nonpart` omitted), `testKeyregOnline`, `testKeyregOnlineNoStateproof`. Live: nonparticipating keyreg reaches `overspend` where the uint form returned HTTP 400. |
| REQ-algorand-013 | `testPayFeeZero`, `testPayFirstValidZero`, `testPayEmptyNote`, `testPayZeroLease`, `testPayEmptyGenesisId`, `testPayZeroAmount`, `testPayAllOmittableZero`, `testAxferZeroAssetId`, `testApplExtraPagesZero`, `testApplCreateZeroSchemas`, `testAcfgCreateDefaultFrozenFalse`. |
| REQ-algorand-014 | `testKeyregNonparticipating`, `testKeyregOffline`, `testAfrzFreeze`, `testAfrzUnfreeze`, `testAcfgCreateDefaultFrozenFalse` — booleans written as `0xC3`, omitted when false, never `0xC2` or an integer. |
| REQ-algorand-015 | `testApplBoxCurrentApp`, `testApplBoxSelfAppId`, `testApplBoxForeignApp`, `testApplBoxAppendPath`, `testApplBoxEmptyName`; `[Box]` `testUndeclaredApplicationIsAppendedToForeignApps`, `testRepeatedReferencesShareOneForeignAppSlot`, `testCurrentApplicationNeverExtendsForeignApps`, `testEncodedTransactionCarriesTheAppendedForeignApp`, `testUnresolvableReferenceThrows`, `testEncodingPropagatesTheUnresolvableReferenceError`. Live: `i` = raw app ID rejected with `Exceeds len(tx.ForeignApps)`; index form accepted. |
| REQ-algorand-016 | `testGroupedAndUngroupedTransactionIDsDiffer`, `testSignedGroupedTransactionReportsGroupedID`, `testGroupedTransactionZeroEncoding`, `testGroupedTransactionOneEncoding`, `testGroupIDIsExactlyTheGoldenValue`, `testGroupIDIsStableAcrossConstruction`. Live: the node's own ID for group member 0 equals `SignedTransaction.id()`. |
| REQ-algorand-017 | `testPayNormal`, `testPayFull`, `testAcfgCreateFull`, `testApplKitchenSink` — unchanged golden bytes for transactions with no zero/empty field; independently diffed pre- vs post-change (clone at 0d8a85f) with identical hex and identical node-reported transaction ID. Single choke point: every `encode(groupID:)` routes through `CanonicalTransactionFields`. |
| REQ-algorand-018 | Suite provenance in the `CanonicalEncodingTests` header: vectors generated from go-algorand v5.0.1-stable `msgp_gen.go` semantics, cross-checked against py-algorand-sdk 2.12.0 with its three deviations catalogued; AGPL-3.0 Falcon/lsig fixtures deliberately not copied. |

