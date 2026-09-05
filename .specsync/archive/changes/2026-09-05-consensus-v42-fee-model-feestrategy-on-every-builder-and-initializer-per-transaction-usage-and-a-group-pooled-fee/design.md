---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: design
---

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
