---
id: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
state: archived
type: feature
base_commit: 4bea6067a5414895918dafcb4fb0cebcf408f4af
---

# Consensus v42 fee model: FeeStrategy on every builder and initializer, per-transaction usage, and a group-pooled fee requirement

## Intent

Consensus v42 fee model: FeeStrategy on every builder and initializer, per-transaction usage, and a group-pooled fee requirement

## Affected Canonical Specs

- `algorand`

## Acceptance Criteria

- Every transaction builder, initializer, and factory accepts a FeeStrategy (.minimum default, .flat, .suggested) resolved against TransactionParams, so a payment built from params whose min-fee is 2000 carries fee 2000 and reproduces the pay_min_fee_from_params golden bytes and transaction ID; .minimum prices consensus v42 usage (one minimum fee plus 100 micro-units per note byte over 1024, application-argument byte over 2048, and program byte over 8192; two minimum fees for a Falcon-1024 envelope) so a 2000-byte-note payment carries 1098 at min-fee 1000; AtomicTransactionGroup and SignedAtomicTransactionGroup expose the pooled usage and requiredFee(minFee:), and checkFees(minFee:) throws FeeError.insufficient with both numbers; every overflow throws FeeError.overflow and nothing saturates; AlgorandConsensus.v42 names the certified protocol and its 1000 microAlgo minimum fee; transactions with an explicit fee encode byte-identically to the base tree (47-line harness diff empty); on a live TestNet v42 node, read-only simulate reports group-usage equal to the SDK usage for a pooled two-payment group (2000000), a 2000-byte-note payment (1097600), an app create with 4000 argument bytes (1195200) and one with 12000 program bytes (1380800), and a mixed pooled group (2292800), each reaching overspend past signature verification; XCTest stays 98 / 20 skipped / 0 failures, Swift Testing grows 76 to 97 with 0 issues on macOS and on Linux swift:6.0-jammy three runs out of three, without editing any predecessor test file; swift build is warning-free; no existing signature is source-breaking.

## No-spec Rationale

Not applicable
