---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: context
---

# Context

## What led here

Consensus v42 (go-algorand v5.0.1-stable, spec
`268b63433a907455d439995bf916f6b296018f4f`, live on MainNet and TestNet) replaced "one minimum
fee per transaction" with a usage model: `PerByteTxnSurcharge = 100` micro-units per byte beyond
the free tiers for notes (1024), application arguments (2048), and programs (8192), and
`PQSchemeFeeContribution("f1") = 2e6` for a Falcon-1024 envelope, checked **once per group** as
`sum(fee) >= ceil(sum(usage) * MinTxnFee / 1e6)`. This SDK priced nothing: 21 initializer and
factory defaults and `PaymentTransactionBuilder`'s stored `fee` hardcoded `MicroAlgos(1000)`, and
`TransactionParams.minFee` was decoded and never read. A payment with a 2000-byte note built by
this package underpaid by 98 microAlgos and a Falcon-signed payment by 2000; the post-quantum
change documented the latter on `PQSigner` and deferred the model to this change, and the
canonical-encoding change recorded the `pay_min_fee_from_params` golden vector (a payment built
from parameters whose `min-fee` is 2000 carries `fee: 2000`) in `DeferredVectors.swift` for it.

## Decisions taken before this session (maintainer, final)

- Minimal core: `FeeStrategy` on every builder and initializer with `.minimum` (default, derived
  from `min-fee`), `.flat(MicroAlgos)`, and `.suggested` (per-byte `fee` when non-zero, floored at
  the minimum); per-transaction v42 usage; a group-pooled requirement helper on
  `AtomicTransactionGroup`, because the network's check is pooled; an `AlgorandConsensus.v42`
  constant naming the certified protocol; roughly fifteen new public bare names, each justified.
- `MicroAlgos` arithmetic and its traps are the next change's business and are untouched here.
- Overflow throws a typed error; a saturating multiply that hands the caller `UInt64.max` as a fee
  is forbidden. The earlier 147-symbol design was rejected for that, for a fictitious group-wide
  LogicSig size pool of 16000, for claiming a sum of per-transaction ceilings always clears the
  pooled requirement, and for enforcing per-transaction LogicSig argument caps that are pooled.

## What this session established

- **The live node agrees with the model to the micro-unit.** Read-only `simulate` on TestNet v42
  reported `group-usage` 2000000 for a pooled two-payment group, 1097600 for a 2000-byte note,
  1195200 for 4000 argument bytes, 1380800 for 12000 program bytes over five extra pages, and
  2292800 for a mixed pooled group, each equal to `SignedAtomicTransactionGroup.feeUsage()`.
- **`overspend` is reached before `CheckGroupFees`.** In `ledger/eval/eval.go` the group fee check
  runs after `eval.transaction` has applied every member, so an unfunded sender fails at
  `overspend` whether its fees are sufficient or one microAlgo short. What `overspend` proves is
  decode and signature verification; what proves the fee model is `group-usage` and
  `group-fees-paid`, which the node computes with `SummarizeFees` independently of evaluation.
  The testing artifact says so rather than repeating the brief's "signature + fee checks passed".
- **The header-field initializers cannot price by usage without breaking source.** They take no
  parameters and are called without `fee:` by exact-only XCTest files that cannot be edited, and
  a throwing default is not expressible. They keep a non-throwing `MicroAlgos` default, now the
  named `AlgorandConsensus.v42.minimumFee` rather than a literal, and every type gains a
  params-based overload that prices a strategy. Byte identity for explicit fees is proven by a
  47-line harness diff against 4bea606.
- **`.suggested` sizes the signed transaction**, as py-algorand-sdk's `estimate_size` and
  js-algorand-sdk's `estimateSize` do: the canonical encoding plus 75 bytes of Ed25519 envelope,
  taken over a draft carrying `min-fee`. The per-byte `fee` is 0 on TestNet today, so the
  strategy resolved to the minimum in every live probe; the non-zero path is unit-tested.
- **`TransactionParams` had no `fee` and no memberwise initializer.** Both are added; `fee`
  decodes as 0 when absent so older fixtures still decode.
- **algonode's free tier can answer 403 `Daily free API quota exceeded`** to a burst; the first
  probe run hit it once and the rerun, minutes later, returned 200 for all seven groups.

## Things ruled out

- Making `Transaction.feeUsage()` a static protocol extension: it must be a requirement with a
  default so `any Transaction` dispatches to `ApplicationCallTransaction`'s override.
- A `TransactionUsage` `Comparable` or operator surface: `<` may or may not be extracted as an
  export and operators are discouraged; `adding(_:)` throws, which an operator cannot express
  cleanly.
- Modelling LogicSig program pricing (per LogicSig beyond 1000 bytes, `lsig.l`): the SDK builds
  no logic signatures; the invariant names the term and leaves it out of the model.
- Editing `TransactionSigner.swift`'s fee note: it remains true (builders price for Ed25519 and a
  Falcon signer must set or add the fee), and touching it would add a supersession edge for a
  doc-only change.

## Supersession set

Exactly the pre-existing files this change modifies, from the archived acceptance manifests
against base 4bea606: `Sources/Algorand/{ApplicationTransaction,AssetTransaction,
KeyRegistrationTransaction,PaymentTransaction,Transaction}.swift` from the canonical-encoding
change, and `specs/algorand/algorand.spec.md` and `specs/algorand/requirements.md` from the
post-quantum change. No test file is edited; `FeeModelTests.swift` is new.

## Supersession lesson

Supersede exactly the pre-existing files the change modifies, and for each file declare an edge
against EVERY archived predecessor whose manifest still holds it at the same digest — an archive
holds every file under its declared paths, changed or not, so a modification stales all of them
and each needs a tuple. Test files cannot be superseded; a change never edits a predecessor's
test file.
