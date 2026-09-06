---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: tasks
---

# Tasks

- [x] T1 Create the workspace at base `4bea606` with `--path Sources/Algorand --path Tests/AlgorandTests --path specs/algorand`, and while still a draft supersede `Sources/Algorand/ApplicationTransaction.swift` (`08ce6414…`), `AssetTransaction.swift` (`ed79480a…`), `KeyRegistrationTransaction.swift` (`1d386f75…`), `PaymentTransaction.swift` (`ad20e93a…`), and `Transaction.swift` (`68f1bed8…`) from the canonical-encoding change, and `specs/algorand/algorand.spec.md` (`9daaf797…`) and `requirements.md` (`e446f365…`) from the post-quantum change.
- [x] T2 Pin the v42 facts in go-algorand v5.0.1-stable: `PerByteTxnSurcharge = 100`, `MaxTxnNoteBytes = 1024`, `MaxAppTotalArgLen = 2048`, `MaxAppTotalProgramLen * (1 + MaxExtraAppProgramPages) = 8192`, `PQSchemeFeeContribution(f1) = 2e6`, `MinTxnFee = 1000`, `FeeForUsage` rounding, and `CheckGroupFees` running after apply.
- [x] T3 `AlgorandConsensus`: `v42` with the exact spec identifier and `minimumFee`, internal constants, internal initializer.
- [x] T4 `TransactionUsage`: `micros`, `adding(_:)`, `fee(minFee:)` at 128-bit width, internal `surcharge` and `header`; `feeUsage` on `Transaction` (default), `ApplicationCallTransaction`, `PQScheme`, `TransactionAuthorization`, `SignedTransaction`; the `feeUsage()` requirement on `Transaction`.
- [x] T5 `FeeStrategy`: `.minimum`, `.flat`, `.suggested`, `fee(for:params:)` with the 75-byte signed-envelope estimate.
- [x] T6 `FeeError`: `.overflow(String)`, `.insufficient(required:paid:)`, descriptions.
- [x] T7 `AtomicTransactionGroup+Fees`: `feeUsage()` and `requiredFee(minFee:)` on both group types, `checkFees(minFee:)` on the signed group with a checked paid-fee sum.
- [x] T8 `TransactionParams`: decode `fee` (0 when absent), public memberwise initializer, `validityWindow(rounds:)` that throws instead of trapping.
- [x] T9 Replace all 22 `MicroAlgos(1000)` sites: 21 defaults become `AlgorandConsensus.v42.minimumFee`; the builder holds a `FeeStrategy` and gains `fee(_ strategy:)` beside `fee(_ fee:)`.
- [x] T10 Add a params-based overload with `fee: FeeStrategy = .minimum`, `params:`, `validRounds: = 1000` beside all 8 memberwise initializers and all 11 factories, delegating to the header-field form with the resolved fee.
- [x] T11 Leave every predecessor test file untouched; add `FeeModelTests` (21 tests) with throwing calls hoisted out of `#expect`, making `pay_min_fee_from_params` live by byte equality through the builder and the initializer.
- [x] T12 `fledge lanes run verify` green: XCTest 98 / 20 skipped / 0 failures; Swift Testing 97 tests in 5 suites, 0 issues; `swift build` warning-free after touching every source file.
- [x] T13 Linux: copy of the tree under the scratchpad, `swift:6.0-jammy` `swift build --build-tests`, then 3 × `timeout 150 swift test --skip-build --disable-xctest`, all exit 0 with 97 tests.
- [x] T14 Byte identity: a harness built against 4bea606 and against this change prints identical output for 20 transactions bare and grouped, 4 signed envelopes standalone and grouped, and one group ID (47 lines).
- [x] T15 Live, read-only (`GET /v2/transactions/params`, `POST /v2/transactions/simulate` only): seven groups whose node `group-usage` equals the SDK usage, including the pooled two-payment group, the 2000-byte note, 4000 argument bytes, 12000 program bytes, and a mixed pooled group; every one reaches `overspend`; evidence in `testing.md`.
- [x] T16 README: a params-based construction example and a "Fees (consensus v42)" section.
- [x] T17 Spec: five files added to the frontmatter; delta with the full `Public API` body plus 17 rows, updated `Purpose`, `Invariants` 10, two behavioural examples, two error rows, inventory paragraph; REQ-algorand-024 to 028.
- [x] T18 Interview answered (`acceptance_criteria`, `public_contract yes`, `architecture_risk yes`); `approve --actor 0xLeif`; `check`; commit; `review --reviewer 0xLeif`; `finalize` with the spec-sync #753 build; archive commit; `fledge attest sign` per commit and `attest verify`; push branch and notes; draft PR with base `feat/pq-envelope`.
