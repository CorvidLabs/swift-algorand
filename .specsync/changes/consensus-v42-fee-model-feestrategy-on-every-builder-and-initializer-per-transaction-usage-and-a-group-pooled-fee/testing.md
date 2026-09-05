---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: testing
---

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
