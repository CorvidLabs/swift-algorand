# Lesson bundle — consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee

Material for folding this change's lessons into the affected specs' `context.md`.
Synthesise from what actually happened below; do not restate the change description.

## What this change was

- **Title**: Consensus v42 fee model: FeeStrategy on every builder and initializer, per-transaction usage, and a group-pooled fee requirement
- **Kind**: Feature
- **Specs**: algorand
- **Paths**: Sources/Algorand, Tests/AlgorandTests, specs/algorand
- **Acceptance**: Every transaction builder, initializer, and factory accepts a FeeStrategy (.minimum default, .flat, .suggested) resolved against TransactionParams, so a payment built from params whose min-fee is 2000 carries fee 2000 and reproduces the pay_min_fee_from_params golden bytes and transaction ID; .minimum prices consensus v42 usage (one minimum fee plus 100 micro-units per note byte over 1024, application-argument byte over 2048, and program byte over 8192; two minimum fees for a Falcon-1024 envelope) so a 2000-byte-note payment carries 1098 at min-fee 1000; AtomicTransactionGroup and SignedAtomicTransactionGroup expose the pooled usage and requiredFee(minFee:), and checkFees(minFee:) throws FeeError.insufficient with both numbers; every overflow throws FeeError.overflow and nothing saturates; AlgorandConsensus.v42 names the certified protocol and its 1000 microAlgo minimum fee; transactions with an explicit fee encode byte-identically to the base tree (47-line harness diff empty); on a live TestNet v42 node, read-only simulate reports group-usage equal to the SDK usage for a pooled two-payment group (2000000), a 2000-byte-note payment (1097600), an app create with 4000 argument bytes (1195200) and one with 12000 program bytes (1380800), and a mixed pooled group (2292800), each reaching overspend past signature verification; XCTest stays 98 / 20 skipped / 0 failures, Swift Testing grows 76 to 97 with 0 issues on macOS and on Linux swift:6.0-jammy three runs out of three, without editing any predecessor test file; swift build is warning-free; no existing signature is source-breaking.

## Evidence

- Verification commit: `bc88fac80d74922af38e1106d491576e686a26e3`
- Base commit: `4bea6067a5414895918dafcb4fb0cebcf408f4af`
- Verified by: `specsync check --spec algorand`

## From the change's context.md

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

## From the change's design.md

# Design

## Usage as a value, fees as one rounding

`TransactionUsage` is go-algorand's `basics.Micros`: a `UInt64` of micro-units where `1_000_000`
is one minimum fee. It has one way to combine (`adding(_:)`) and one way to become money
(`fee(minFee:)`, `ceil(micros * minFee / 1_000_000)` at 128-bit width), both throwing
`FeeError.overflow` rather than saturating. The v42 constants are internal statics on
`AlgorandConsensus`, documented with their Go names, and every surcharge goes through one
internal `surcharge(byteCount:free:)`.

`Transaction` gains a `feeUsage()` requirement with a default (header usage) so that
`any Transaction` dispatches to `ApplicationCallTransaction`'s override, which adds the program
and argument terms. `PQScheme.feeUsage` and `TransactionAuthorization.feeUsage` are constants, so
`SignedTransaction.feeUsage()` is a sum and a Falcon signer can be priced before signing with
`group.feeUsage().adding(PQScheme.falcon1024.feeUsage)`.

## The strategy, resolved for one transaction

`FeeStrategy.fee(for:params:)` needs a transaction to read usage and size from, and the fee is
one of the transaction's fields. Every params-based initializer therefore builds a draft carrying
`min-fee`, resolves the strategy over it, and delegates to the header-field initializer with the
resolved fee. Factories delegate to the params-based initializer, so the 19 overloads are
signature plus argument list and nothing else; they were generated from the legacy signatures so
that no parameter could be dropped.

`.suggested` sizes the draft's canonical encoding plus 75 bytes (`0x82`, `sig`, `bin8` header,
64 signature bytes, `txn`), the official SDKs' estimate, and takes the maximum with the exact
minimum. With `fee` 0 it is the minimum.

## The group, priced as a whole

`AtomicTransactionGroup.feeUsage()` and `requiredFee(minFee:)` sum members as Ed25519-signed;
`SignedAtomicTransactionGroup` sums envelopes and adds `checkFees(minFee:)`, which throws
`FeeError.insufficient(required:paid:)` with both totals. Because the fee is signed and hashed
into the group ID, the documented sequence is build drafts, ask the group, rebuild the payer.

## What stays exactly as it was

The header-field initializers and factories keep their signatures and a non-throwing default,
now `AlgorandConsensus.v42.minimumFee`. `encode(groupID:)` is untouched in every type, so an
explicit fee produces the same bytes as every previous release. `MicroAlgos`, `AlgorandError`,
`SignedTransaction`, `MessagePackWriter`, and the canonical field choke point are unchanged.

## Public surface

Seventeen new bare names: `FeeStrategy`, `minimum`, `flat`, `suggested`, `TransactionUsage`,
`micros`, `adding`, `feeUsage`, `AlgorandConsensus`, `v42`, `identifier`, `minimumFee`,
`requiredFee`, `checkFees`, `FeeError`, `overflow`, `insufficient`. `fee`, `init`, `params`,
`validRounds`, and the factory names already existed. No source-breaking change.

## Out of scope, deliberately

`MicroAlgos` arithmetic safety (the next change), LogicSig program pricing (no logic signatures
are built here), client-side enforcement of the absolute size maxima, and group-level fee planning
that rewrites members' fees (the sequence is three lines and the fee is signed data).

## From the change's testing.md

# Testing

## The suite

One new Swift Testing suite, `Tests/AlgorandTests/FeeModelTests.swift` (21 tests); no XCTest file
and no predecessor Swift Testing file is edited. Fixtures are the canonical suite's TestNet genesis
and accounts A and B, the envelope suite's account A key, the first golden post-quantum key, and
`DeferredVectors.payMinFeeFromParamsHex` / `payMinFeeFromParamsTxID`, read but never edited.
Throwing calls are hoisted out of `#expect` for the Swift 6.0 toolchain's macro.

| Test | What it pins |
|---|---|
| `testMinimumStrategyReadsMinFeeFromParams` | `pay_min_fee_from_params`: `min-fee` 2000 → `fee: 2000`, bytes and ID equal through the builder and the params-based initializer |
| `testMinimumStrategyPricesUsage` | plain payment 1000; 2000-byte note 1098 |
| `testFlatStrategyIsCarriedVerbatim` | 5000 verbatim; 0 omitted from the encoding |
| `testSuggestedStrategyFloorsAtMinimum` | `fee` 0 → minimum, byte-identical to the explicit form; `fee` 1 still the minimum; `fee` 30 → `30 * (size + 75)` |
| `testStrategyResolvesForAnyTransaction` | `fee(for:params:)` by hand: 1515 / 42 / 1515 at `min-fee` 1500 for a 1124-byte note |
| `testBuilderFeeOverloads` | `fee(MicroAlgos)` pins, `fee(FeeStrategy)` chooses, default is `.minimum` |
| `testHeaderFieldInitializersDefaultToTheCertifiedMinimum` | `AlgorandConsensus.v42` identifier and 1000; four header-field forms default to it |
| `testParamsInitializersAndFactoriesAcrossTypes` | all 8 params-based initializers and 11 factories: fee, validity window, genesis fields, `onCompletion` mapping, `nonparticipation` |
| `testParamsInitializerMatchesHeaderFieldInitializer` | params-based payment and application call encode identically to the header-field form |
| `testHeaderUsageIsOneFeePlusNoteSurcharge` | notes of 0 / 1024 / 1025 / 2000 / 4096 bytes at `min-fee` 1000 and 2000 |
| `testNonApplicationTypesUseHeaderUsageOnly` | `axfer` with a note, `acfg`, `keyreg` |
| `testApplicationUsagePricesArgumentsAndPrograms` | free and priced arguments, free and priced programs, one priced byte, everything at once, `apep` alone free |
| `testSignatureUsage` | Ed25519 0, Falcon-1024 2e6, unknown scheme 0, signed transactions 1e6 and 3e6 |
| `testGroupUsageIsPooled` | two members at 1001 each pool to 2001 |
| `testSignedGroupCheckFees` | 2000 + 0 passes; 1999 + 0 → `insufficient(required: 2000, paid: 1999)` |
| `testSignedGroupCountsPostQuantumEnvelopes` | a Falcon envelope raises 2000 to 4000, equal to `adding(PQScheme.falcon1024.feeUsage)` |
| `testFeeRoundsUpOnce` | exact, tiny and half remainders, scaled `min-fee`, zero, `adding` |
| `testOverflowThrowsInsteadOfSaturating` | product, sum, suggested product, paid-fee total all throw; `UInt64.max` usage at `min-fee` 1e6 is exactly `UInt64.max` |
| `testValidRoundsOverflowIsAnError` | `lastRound = UInt64.max` + 1 round → `AlgorandError.invalidTransaction` |
| `testTransactionParamsDecodesFeePerByte` | `fee` decoded, absent `fee` → 0 |
| `testFeeErrorsDescribeThemselves` | both descriptions |

## Results

| Platform | XCTest | Swift Testing |
|---|---|---|
| macOS, `fledge lanes run verify` (`swift build` + `CI=true swift test`) | 98 executed, 20 skipped, 0 failures (unchanged from 4bea606) | 97 tests in 5 suites, 0 issues (was 76 in 4) |
| Linux, `swift:6.0-jammy`, `swift build --build-tests` then 3 × `timeout 150 swift test --skip-build --disable-xctest` | not run (swift-corelibs-xctest #504) | 97 tests passed, exit 0, three runs out of three |

`swift build` is warning-free after `touch`ing every file under `Sources/Algorand`.

## Byte identity against 4bea606

The base tree's `Package.swift` and `Sources` were exported with `git archive` and a harness was
built once against that copy and once against this change. It encodes 20 transactions (payments
with an explicit fee, the default fee, fee 0 with note, lease, rekey and close, and fee 2000;
`acfg` create with every field and with defaults; `axfer` opt-in, transfer with close, clawback;
`afrz`; `acfg` update and destroy; `keyreg` online, offline, nonparticipating; `appl` create with
9000-byte programs, 3000-byte arguments, boxes and seven extra pages, call, opt-in, delete), each
bare and under a group ID, plus four signed envelopes with a fixed signature, standalone and
grouped, plus one group identifier. The two 47-line outputs are identical (`cmp` silent).

## Live verification (read-only)

`GET https://testnet-api.algonode.cloud/v2/transactions/params` reported round 67020843,
`min-fee` 1000, `fee` 0, and `consensus-version`
`https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f`,
equal to `AlgorandConsensus.v42.identifier`. Each group was signed with unfunded throwaway
accounts (seeds `0x51…` and `0x52…`) and posted to `POST /v2/transactions/simulate` with
`Content-Type: application/msgpack` and the body `{"txn-groups":[{"txns":[<stxn>, …]}]}`, the
envelopes spliced in as the SDK encoded them. `POST /v2/transactions` was never called.

The node's `group-usage` is `SummarizeFees` over the group; the requirement column is
`ceil(group-usage * 1000 / 1e6)`. The SDK columns are `SignedAtomicTransactionGroup.feeUsage()`
and `requiredFee(minFee: 1000)`.

| Probe | HTTP | node `group-usage` | SDK usage | node requirement | SDK `requiredFee` | node `group-fees-paid` | SDK fees paid | `failure-message` |
|---|---|---|---|---|---|---|---|---|
| (a) two payments, txn0 `.flat(requiredFee)` = 2000, txn1 `.flat(0)` | 200 | 2000000 | 2000000 | 2000 | 2000 | 2000 | 2000 | `transaction POR3WWPG7BHUJY5SQB6ZEEPRTH3IGPZSUEFXAP7CBOICTYAP4EIQ: overspend (account YBIMKY32…, … tried to spend 2mA)` |
| (a′) control: same group, txn0 1999 | 200 | 2000000 | 2000000 | 2000 | 2000 | 1999 | 1999 | `transaction UA6JC45E…: overspend (… tried to spend 1.999mA)` |
| (b) payment with a 2000-byte note, `.minimum` | 200 | 1097600 | 1097600 | 1098 | 1098 | 1098 | 1098 | `transaction XA3CXO4V…: overspend (… tried to spend 1.098mA)` |
| (b′) control: same payment at `.flat(1000)` | 200 | 1097600 | 1097600 | 1098 | 1098 | 1000 | 1000 | `transaction YZHBKOWB…: overspend (… tried to spend 1mA)` |
| (c) `appl` create, two 2000-byte arguments, `.minimum` | 200 | 1195200 | 1195200 | 1196 | 1196 | 1196 | 1196 | `transaction DPGVNHRJ…: overspend (… tried to spend 1.196mA)` |
| (c′) `appl` create, 10000 + 2000 program bytes, `apep` 5, `.minimum` | 200 | 1380800 | 1380800 | 1381 | 1381 | 1381 | 1381 | `transaction K3RFUTNP…: overspend (… tried to spend 1.381mA)` |
| (d) 3000-byte-note payment covering an `appl` create with 3000 argument bytes at `.flat(0)` | 200 | 2292800 | 2292800 | 2293 | 2293 | 2293 | 2293 | `transaction ML5T7WXO…: overspend (… tried to spend 2.293mA)` |

Every `group-usage` equals the SDK's usage and every requirement equals `requiredFee`. The full
`failure-message` for each row is `transaction <ID>: overspend (account
YBIMKY32IT5IMKP76PGMZYRQBSZWFJR5THMV7RKBIUTG6QZSIRNACQA7YU, data {AccountBaseData:{Status:Offline
MicroAlgos:0.0A …}}, tried to spend <fee>)`. What `overspend` shows: the envelope decoded, the
group ID matched, and Ed25519 signature verification passed, so evaluation reached the fee
deduction of a zero-balance sender. What it does not show: `CheckGroupFees` itself, which
`ledger/eval/eval.go` runs after every member has been applied, so with unfunded senders the
one-microAlgo-short control (a′) fails at `overspend` too. The fee requirement is therefore
verified through `group-usage` and `group-fees-paid`, which the node computes with
`SummarizeFees` before returning, and locally through `checkFees(minFee:)`, which rejects (a′)
with `insufficient(required: 2000, paid: 1999)`.

The first run of the same seven groups received one `403 Daily free API quota exceeded` from
algonode on probe (a) and 200 with the figures above on the other six; the rerun a few minutes
later returned 200 for all seven, which is the run recorded here. Raw responses are in the
scratchpad (`fee-work/feelive-raw-responses-2.json`).

## Requirement evidence

All tests are in `Tests/AlgorandTests/FeeModelTests.swift`.

| Requirement | Evidence |
|---|---|
| REQ-algorand-024 | `testMinimumStrategyReadsMinFeeFromParams`, `testMinimumStrategyPricesUsage`, `testFlatStrategyIsCarriedVerbatim`, `testSuggestedStrategyFloorsAtMinimum`, `testStrategyResolvesForAnyTransaction`, `testBuilderFeeOverloads`, `testParamsInitializersAndFactoriesAcrossTypes`, `testHeaderFieldInitializersDefaultToTheCertifiedMinimum`, `testTransactionParamsDecodesFeePerByte`, `testValidRoundsOverflowIsAnError`; XCTest 98 / 20 skipped / 0 failures unchanged. |
| REQ-algorand-025 | `testHeaderUsageIsOneFeePlusNoteSurcharge`, `testNonApplicationTypesUseHeaderUsageOnly`, `testApplicationUsagePricesArgumentsAndPrograms`, `testSignatureUsage`, `testFeeRoundsUpOnce`; live probes (b), (c), (c′). |
| REQ-algorand-026 | `testGroupUsageIsPooled`, `testSignedGroupCheckFees`, `testSignedGroupCountsPostQuantumEnvelopes`; live probes (a), (a′), (d). |
| REQ-algorand-027 | `testOverflowThrowsInsteadOfSaturating`, `testValidRoundsOverflowIsAnError`, `testFeeErrorsDescribeThemselves`; `git diff 4bea606 -- Sources/Algorand/MicroAlgos.swift Sources/Algorand/AlgorandError.swift` is empty. |
| REQ-algorand-028 | `testHeaderFieldInitializersDefaultToTheCertifiedMinimum`, `testParamsInitializerMatchesHeaderFieldInitializer`; the 47-line byte-identity harness; the node's `consensus-version`. |

## Where these lessons go

- `specs/algorand/context.md`
