---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: plan
---

# Plan

## Objective

Make the bytes this SDK signs identical to the bytes a consensus v42 node re-derives and verifies
against, so that signed transactions are accepted. Thirteen golden vectors currently fail; all
thirteen pass at the end. Two further failures are deferred, by decision, to named follow-up
changes.

## Sequencing principle

**Vectors first, encoder second.** The suite lands red in its own commit. Every later commit is
justified by a specific test flipping green, and the 37 already-passing vectors act as the
regression fence for byte-identical output. Reversing that order would leave the fix asserted rather
than proved, and would make a silent regression in already-correct transactions invisible.

## Commit sequence

| # | Commit | Tasks | Gate |
|---|---|---|---|
| 1 | `Add: canonical MessagePack golden-vector conformance suite` | T1–T4 | Baseline recorded on both platforms; the failing set is exactly the 13 in scope plus the 2 deferred |
| 2 | `Add: CanonicalTransactionFields, the single omit-empty choke point` | T5, T6 | Builds; no behaviour change yet |
| 3 | `Fix: route payment encoding through canonical omit-empty` | T7 | 6 vectors green; 6 payment vectors byte-identical |
| 4 | `Fix: encode nonpart as a MessagePack bool and omit it when false` | T8 | `keyreg_nonparticipating` green |
| 5 | `Fix: route asset encoding through canonical omit-empty` | T9 | `axfer_zero_asset_id` green; 11 asset vectors byte-identical |
| 6 | `Fix: route application encoding through canonical omit-empty` | T10 | 13 application vectors byte-identical |
| 7 | `Fix: translate box references to foreign-application indexes` | T11–T15 | 4 vectors green; `boxes:` signature unchanged, behaviour change called out in the message |
| 8 | `Fix: report the grouped transaction ID from SignedTransaction.id()` | T16 | `group_txn0_grouped` green |
| 9 | `Update: adopt canonical-encoding requirements in the algorand spec` | T19, T20 | SpecSync coverage 100%; docs updated |

Each commit is independently green: `swift build` and `CI=true swift test` pass at every one of the
nine points, with the canonical suite's failure count monotonically decreasing.

## Verification gates

1. **Byte equality, not shape.** Every canonical assertion compares a full hex string and a full
   base32 transaction ID.
2. **Both platforms.** macOS and Linux (`swift:6.0-jammy`). The two platforms differ only in one
   skip — Darwin's CryptoKit randomizes the Ed25519 nonce, so raw signature bytes are not
   reproducible there.
3. **No regression fence.** The 37 vectors green before commit 1 must be green, and byte-identical,
   after commit 9.
4. **Live node.** Independent confirmation on TestNet via `POST /v2/transactions/simulate` for each
   fixed vector (T18). This is the only gate that proves the *network* accepts the result rather
   than that the SDK agrees with a Python script.
5. **Spec sync.** `deltas/algorand.md` applied, `require_coverage = 100` still satisfied at 344
   export rows and 21 source files.

## Risks and how each is contained

| Risk | Containment |
|---|---|
| The choke point perturbs an already-correct encoding | The 37 passing vectors are the fence, and they run at every commit |
| The vectors themselves are wrong | go-algorand v5.0.1-stable's marshaller is the authority; T18 re-verifies against a live node running that exact binary, which is an oracle the vectors cannot fake |
| Someone later "fixes" the encoder toward py-algorand-sdk | The three deviations are documented in `research.md` §7, in `context.md`, and inline in the suite next to the vectors that expose them |
| A `boxes:` entry silently changes meaning | The tuple was always documented `(app_id, box_name)`; only the encoder disagreed, and the old encoding could never produce an accepted transaction, so no working caller exists. Called out in the commit message and in `docs.md` |
| Appending to `apfa` inflates the array past the caller's intent | Bounded client-side at eight foreign applications, failing with `AlgorandError.invalidTransaction` rather than deferring to a node rejection |
| Transaction IDs change for transactions that carried a zero field | Intentional and unavoidable — the old IDs never existed on chain. Documented in `docs.md` |

## Definition of done

- Swift Testing: macOS 56 pass / 9 skipped-by-trait / 0 issues; Linux 57 pass / 8 skipped / 0
  issues, on both swift:6.0 and swift:6.1, 5/5 runs each via `swift test --disable-xctest`.
- Whole-package `swift build` warning-free on both platforms; macOS `CI=true swift test` green
  with XCTest at its pre-change 98/20/0 baseline. Linux end-to-end `swift test` is gated by the
  pre-existing XCTest suite's upstream deadlock (#504), out of this change's scope.
- No forward-looking placeholders in this suite; deferred vectors are recorded in
  `DeferredVectors.swift` or by name, and each follow-up change adds its own test file.
- Zero new public symbols; export table unchanged at 344 rows; SpecSync coverage 100%.
- `deltas/algorand.md` applied to `specs/algorand/`.
