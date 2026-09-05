---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: docs
---

# Docs

## What changed for a caller

- `PaymentTransactionBuilder` now prices its fee: with no `fee(_:)` call the transaction carries
  `ceil(usage * params.minFee / 1_000_000)` instead of a fixed 1000. On a network whose `min-fee`
  is 1000 an ordinary payment is unchanged; a payment with a note over 1024 bytes now carries
  the fee the network requires (1098 for 2000 bytes) instead of underpaying. `fee(MicroAlgos)`
  still pins an exact fee; `fee(FeeStrategy)` is new; `build()` can now throw `FeeError.overflow`.
- Every transaction type gains an initializer, and every factory an overload, that takes
  `params: TransactionParams`, `fee: FeeStrategy = .minimum`, and `validRounds: UInt64 = 1000`
  in place of `fee: MicroAlgos`, `firstValid`, `lastValid`, `genesisID`, and `genesisHash`. They
  throw; the header-field forms do not and are unchanged apart from their default now reading
  `AlgorandConsensus.v42.minimumFee` (still 1000).
- `TransactionParams` decodes the per-byte `fee` and has a public memberwise initializer.
- `Transaction` has a new requirement, `feeUsage()`, with a default implementation; an external
  conformer compiles unchanged and inherits the header-only usage.
- New: `FeeStrategy`, `TransactionUsage`, `AlgorandConsensus`, `FeeError`, `feeUsage` on
  transactions, envelopes, schemes, authorizations, and groups, `requiredFee(minFee:)` on both
  group types, and `checkFees(minFee:)` on the signed group.

## Source-breaking changes

None found. Every existing initializer, factory, and builder call compiles unchanged: the
params-based overloads require a `params:` label the header-field forms lack, and their `fee`
parameter is a different type. Callers with their own `Transaction` conformance gain a defaulted
requirement. Callers with their own extension named `feeUsage` on a `Transaction`, `PQScheme`, or
`TransactionAuthorization` would now collide; none is known.

## Where the documentation lives

- Every public symbol carries a doc comment. `TransactionUsage` carries the contribution table
  and what contributes nothing; `FeeStrategy` the three strategies and the 75-byte estimate;
  `AlgorandConsensus` the certified identifier and why `minimumFee` exists;
  `AtomicTransactionGroup+Fees` the build-ask-rebuild sequence and why a Falcon signer's usage is
  added by hand before signing; `FeeError` why nothing saturates.
- `README.md` gained a params-based construction example and a "Fees (consensus v42)" section
  with the three strategies, the pooled-group sequence, and `checkFees`.
- The living spec's `Purpose`, `Public API`, `Invariants` (10), `Behavioral Examples`,
  `Error Cases`, and inventory sections are updated through the delta; REQ-algorand-024 to 028
  are the contract.
- The DocC catalog (`Sources/Algorand/Algorand.docc`) is not modified; its symbol pages are
  generated from the doc comments above, and `GettingStarted.md`'s header-field examples still
  compile and still carry their explicit `fee: MicroAlgos(1000)`.

## Facts worth repeating anywhere the SDK is described

- v42 usage: 1_000_000 micro-units per transaction; 100 per note byte over 1024, per argument
  byte over 2048, per program byte over 8192; 2_000_000 for a Falcon-1024 envelope; nothing for
  `apep`, references, schemas, or Ed25519.
- Requirement: `ceil(sum(usage) * min-fee / 1_000_000)` over the whole group, against the sum of
  fees; a member may pay 0.
- `.suggested` is `max(minimum, fee * (encoded size + 75))`; the per-byte `fee` is 0 on MainNet
  and TestNet unless the pool is congested.
- The header-field initializers default to 1000 and never price usage; use the params-based
  forms or `FeeStrategy.fee(for:params:)`.
