---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: tasks
---

# Tasks

Ordered. The golden vectors land **before** the encoder change, so every subsequent step is proved
by a test flipping from red to green rather than asserted in a commit message.

## Phase 1 — Make the defect visible

- [x] **T1. Land the golden-vector suite, red.** Add `Tests/AlgorandTests/CanonicalEncodingTests.swift`
      (58 cases). Assert byte equality against hex literals plus the transaction ID; never
      `count > 0` or substring containment. Do not touch `Sources/` in this commit.
- [x] **T2. Record the baseline.** `swift test --filter CanonicalEncodingTests` on macOS and on
      Linux (`swift:6.0-jammy`). Expected: macOS 36 pass / 15 fail / 7 skip; Linux 37 pass /
      15 fail / 6 skip. The failing set must be exactly the 15 named in `testing.md`; anything else
      means the vectors are wrong, not the encoder.
- [x] **T3. Correct the stale prose in the suite.** The `keyreg_nonparticipating` vector's
      description still says the node "rejects the transaction outright" as a decode type error.
      That diagnosis is refuted (`research.md` §3). Rewrite it to name the signing-preimage
      mechanism. The bytes are correct and do not change.
- [x] **T4. Mark the two deferred vectors.** `signed_ed25519_rekeyed_sgnr`
      (`testRekeyedEnvelopeCarriesSgnr`) and `pay_min_fee_from_params`
      (`testBuilderDerivesFeeFromSuggestedParameters`) are NOT kept as placeholders: test files are
      exact-only inputs of the change that writes them, so follow-up changes add their own suites.
      The fee vector's bytes move to `DeferredVectors.swift`; the envelope vectors are carried by
      the envelope change's suite. Baseline becomes 13 failures.

## Phase 2 — The choke point

- [x] **T5. Add `Sources/Algorand/CanonicalTransactionFields.swift`.** `internal struct` with the
      eight typed setters from `design.md` plus `setHeader(...)`. Document each against the
      go-algorand type it mirrors. Keep the `blob:` / `digest:` distinction: variable slices omit on
      `count == 0`; fixed arrays omit on all-zero.
- [x] **T6. Give the setters a zero-address test.** `set(_:address:)` must omit the all-zero address
      without exposing anything public — no `Address.isZero` on the public surface.
- [x] **T7. Route `PaymentTransaction.encode` through the choke point.** Turns `pay_fee_zero`,
      `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`, `pay_empty_genesis_id`,
      `pay_all_omittable_zero` green. `pay_normal`, `pay_full`, `pay_close_remainder_to`,
      `pay_rekey_to`, `pay_zero_amount`, `pay_large_fee_uint64` must stay green and byte-identical.
- [x] **T8. Route `KeyRegistrationTransaction.encode`, and change `nonpart` to `.bool(true)`.**
      Turns `keyreg_nonparticipating` green. `keyreg_online`, `keyreg_offline`,
      `keyreg_online_no_stateproof` stay green.
- [x] **T9. Route all five `AssetTransaction` encoders and the nested `apar` map.** Turns
      `axfer_zero_asset_id` green. The eleven other asset vectors stay green and byte-identical.
      `apar.t` stops being written unconditionally; `apar.am` becomes a `digest:`; `apar.m/r/f/c`
      become `address:`. `strictEmptyAddressChecking` behaviour is untouched.
- [x] **T10. Route `ApplicationTransaction.encode`.** Nested `apgs`/`apls` use `nested:` so an
      all-zero schema disappears instead of encoding as `{}` — `appl_create_zero_schemas` must stay
      green through the rewrite, not merely afterwards.

## Phase 3 — Box references

- [x] **T11. Add `Sources/Algorand/CanonicalBoxReferences.swift`.** `internal struct` returning both
      the translated `[Reference]` (`index`, `name`) and the extended `foreignApplications`, so
      `apfa` and `apbx` are always encoded from the same array. `maximumForeignApplications = 8`.
      **No new public symbol** — `boxes: [(UInt64, Data)]?` stays exactly as it is.
- [x] **T12. Wire it into `ApplicationCallTransaction.encode`.** Build `apfa` from the translation
      result, not from the caller's array, then encode `apbx` against it. Omit `i` when the index is
      0; omit `n` when the name is empty. Turns `appl_box_self_app_id`, `appl_box_foreign_app`,
      `appl_box_empty_name`, `appl_kitchen_sink` green.
- [x] **T13. Throw on the ninth foreign application.** Appending past
      `maximumForeignApplications` raises `AlgorandError.invalidTransaction`. No new error case.
- [x] **T14. Add `Tests/AlgorandTests/CanonicalBoxReferenceTests.swift`.** The four translation rules
      in isolation, including the append path and the limit, which the encoding vectors do not reach.
- [x] **T15. Add one encoding vector for the append path.** No existing vector covers a box on an
      application absent from `apfa`. Generate it with `gen_vectors.py` so its bytes carry the same
      authority as the rest.

## Phase 4 — Grouped identity

- [x] **T16. `SignedTransaction.id()` hashes `transaction.encode(groupID: groupID)`.** Turns
      `group_txn0_grouped` (`testSignedGroupedTransactionReportsGroupedID`) green. Leave
      `Transaction.id()` alone: `AtomicTransactionGroup.computeGroupID` depends on the ungrouped
      encoding, and `testGroupIDIsExactlyTheGoldenValue` proves it.

## Phase 5 — Prove and record

- [x] **T17. Full suite, both platforms.** Result: macOS `CI=true swift test` — XCTest 98 tests /
      20 skipped / 0 failures (the pre-change baseline) and Swift Testing 65 tests in 2 suites,
      56 passed / 9 skipped by trait / 0 issues. Linux swift:6.0-jammy and swift:6.1-jammy —
      the ported suites (`swift test --disable-xctest`) 57 passed / 8 skipped / 0 issues, 5/5 runs
      each, ~0.015s. The legacy XCTest suite hangs on Linux under Docker Desktop (5/5 runs, hang
      point moving, always inside a pre-existing test) because of the open corelibs-xctest
      deadlock (#504); that exposure predates this change, is unchanged by it, and is why the two
      new suites were moved to Swift Testing. See research.md and testing.md.
- [x] **T18. Re-verify against the live node.** For each of the 13 fixed vectors, submit the new
      bytes to `POST https://testnet-api.algonode.cloud/v2/transactions/simulate` and confirm
      HTTP 200 reaching balance application, where the pre-change bytes returned HTTP 400
      "At least one signature didn't pass verification". Read-only lane; never `POST /v2/transactions`.
- [x] **T19. Apply `deltas/algorand.md`.** `files:` 20 → 22 entries, export table unchanged at 344
      rows, new invariants 6 and 7, amended acceptance criteria on REQ-algorand-002 and -007, new
      REQ-algorand-013…018, spec `version: 4`.
- [x] **T20. Docs.** Done as the `boxes` doc comment on `ApplicationCallTransaction` and the
      commit message's "Silent behavioural changes for callers" section. Release note covering the two silent behaviour changes: transaction IDs change
      for any transaction that previously carried a zero or empty field, and a `boxes:` entry naming
      a foreign application now works (and may add an `apfa` entry the caller did not write). No API
      migration is required.
