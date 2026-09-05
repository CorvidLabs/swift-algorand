---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: plan
---

# Plan

## Shape of the change

Five new source files, five modified source files, one new test suite, no modified test file.

| File | Role |
|---|---|
| `Sources/Algorand/AlgorandConsensus.swift` (new) | `AlgorandConsensus.v42`: the spec identifier and `MinTxnFee`; internal v42 constants (`PerByteTxnSurcharge`, the three free tiers, the Falcon-1024 contribution) |
| `Sources/Algorand/TransactionUsage.swift` (new) | `TransactionUsage` (`micros`, `adding`, `fee(minFee:)` at 128-bit width); `feeUsage` for `Transaction` (default), `ApplicationCallTransaction`, `PQScheme`, `TransactionAuthorization`, `SignedTransaction` |
| `Sources/Algorand/FeeStrategy.swift` (new) | `FeeStrategy` and `fee(for:params:)` |
| `Sources/Algorand/FeeError.swift` (new) | `FeeError.overflow`, `.insufficient` |
| `Sources/Algorand/AtomicTransactionGroup+Fees.swift` (new) | `feeUsage()` and `requiredFee(minFee:)` on both group types, `checkFees(minFee:)` on the signed one |
| `Sources/Algorand/Transaction.swift` (modified, superseded from the canonical change) | `TransactionParams.fee`, a public memberwise initializer, `validityWindow(rounds:)`; the `feeUsage()` protocol requirement |
| `Sources/Algorand/PaymentTransaction.swift` (modified, canonical) | Named default; params-based initializer; builder holds a `FeeStrategy` with two `fee(_:)` overloads |
| `Sources/Algorand/ApplicationTransaction.swift`, `AssetTransaction.swift`, `KeyRegistrationTransaction.swift` (modified, canonical) | Named defaults; a params-based overload beside every initializer and factory (1 + 6, 6 + 2, 1 + 3) |
| `Tests/AlgorandTests/FeeModelTests.swift` (new) | 21 Swift Testing tests |

## Steps, in the order they were taken

1. Read the base tree, the two archived changes' artifacts and lesson bundle, the rejected
   design, and go-algorand v5.0.1-stable's `transaction.go`, `application.go`, `signedtxn.go`,
   `config/consensus.go`, `overflow.go` (`FeeForUsage`), and `eval.go` (`CheckGroupFees` and its
   position after apply).
2. Write the five new files; add the `feeUsage()` requirement, `TransactionParams.fee`, the
   memberwise initializer, and the checked validity window to `Transaction.swift`; replace the
   22 `MicroAlgos(1000)` sites (21 defaults become `AlgorandConsensus.v42.minimumFee`, the
   builder's stored fee becomes a `FeeStrategy`); generate the 19 params-based overloads from
   the legacy signatures so no parameter is dropped.
3. Write `FeeModelTests` with throwing calls hoisted out of `#expect`; make the
   `pay_min_fee_from_params` vector live through both the builder and the initializer.
4. Verify: `fledge lanes run verify` green; XCTest 98 / 20 skipped / 0 failures; Swift Testing
   76 → 97 with 0 issues; a forced full recompile with zero warnings; Linux `swift:6.0-jammy`
   build plus three test runs; the byte-identity harness against 4bea606; seven read-only
   TestNet `simulate` probes compared with the SDK's usage.
5. Spec: add the five files to the frontmatter; generate the delta from the live spec so the
   `Public API` body is verbatim plus 17 rows; write the artifacts; answer the interview;
   `approve`, `check`, commit, `review`, `finalize` (patched build #753), archive commit,
   attest, push, draft PR stacked on #18.

## Risks weighed

- A params-based overload beside a header-field one could be ambiguous. It is not: the two forms
  each require a label the other lacks (`params:` versus `firstValid:` and friends) and the
  `fee` parameter types differ, so every existing call resolves as before.
- `.minimum` on the header-field forms would have been the more correct default, but it needs
  `min-fee` and a throwing initializer; both break exact-only XCTest files. The named constant
  keeps their bytes identical and points at the params-based form in its documentation.
- The 75-byte envelope estimate is an estimate. It matches the official SDKs' practice and only
  feeds `.suggested`, which is floored at the exact v42 minimum.
