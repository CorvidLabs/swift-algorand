---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: requirements
---

# Requirements

The canonical text lives in `deltas/algorand.md` (REQ-algorand-024 through REQ-algorand-028).
This artifact records what each requirement is for and what it deliberately does not ask.

## REQ-algorand-024: a `FeeStrategy` on every builder and params-based initializer

`.minimum` reads `min-fee` and prices the transaction's own usage; `.flat` is verbatim, zero
included; `.suggested` is the legacy per-byte suggestion floored at the minimum. The strategy is
resolved for the transaction alone, which is only the network's answer for a group of one, and
the requirement says so. The header-field forms keep their signatures and a named default.

Not asked: pricing a group at build time. The fee is in the signed bytes and in the group ID, so
the caller rebuilds the paying member with the group's requirement; the group helper is the
authority.

## REQ-algorand-025: per-transaction usage, exactly go-algorand's

`Header.FeeContribution` (notes), `ApplicationCallTxnFields.feeContribution` (arguments and
programs), `PQSchemeFeeContribution` (Falcon-1024), and `FeeForUsage`'s rounding, pinned by unit
figures and by a live node's `group-usage`.

Not asked: enforcing the absolute maxima (4096 note bytes, 16384 argument bytes,
`2048 * (1 + apep)` program bytes). The model prices; the node rejects, and pricing past a
maximum is a fee the node would refuse regardless.

## REQ-algorand-026: the group requirement is pooled

One rounding over the sum, compared with the sum of fees; a member may pay zero. Signed groups
count post-quantum envelopes; unsigned groups assume Ed25519 and document how to add a Falcon
signer's usage before signing.

Not asked: a claim that per-member minimums always clear the pooled requirement. They do for the
terms this model prices, by the ceiling inequality, but the group helper exists precisely so no
caller has to reason about it.

## REQ-algorand-027: overflow is an error

Every multiply and sum in the model reports overflow and throws `FeeError.overflow`; nothing
saturates. `FeeError` is the only new error type; `AlgorandError` gains no case and `MicroAlgos`
is untouched.

## REQ-algorand-028: the certified protocol, and byte identity

`AlgorandConsensus.v42` is the exact identifier a node reports plus the 1000 microAlgo
`MinTxnFee`. Explicit-fee transactions encode as they always have, proven against 4bea606.

## Public surface added (17 bare names)

| Symbol | Kind | Why it must be public |
|---|---|---|
| `FeeStrategy`, `.minimum`, `.flat`, `.suggested` | enum | The maintainer's decision: how a fee is chosen on every builder and initializer |
| `TransactionUsage`, `micros`, `adding(_:)` | struct | The usage value the node's `group-usage` reports; `adding` throws where an operator could not |
| `feeUsage` | method on `Transaction`, `SignedTransaction`, both group types; property on `PQScheme`, `TransactionAuthorization` | One name for one quantity at every level, so a caller can compose a Falcon signer's cost before signing |
| `AlgorandConsensus`, `.v42`, `identifier`, `minimumFee` | struct, constant | Names the certified protocol and its `MinTxnFee`, the default the header-field forms fall back to |
| `requiredFee(minFee:)` | method on both group types | The pooled requirement, the maintainer's named helper |
| `checkFees(minFee:)` | method on `SignedAtomicTransactionGroup` | The strict counterpart, because `simulate` hides a fee shortfall in an HTTP 200 |
| `FeeError`, `.overflow`, `.insufficient` | enum | The typed failures without touching `AlgorandError` |

Reused names, no new rows: `fee` (`FeeStrategy.fee(for:params:)`, `TransactionUsage.fee(minFee:)`,
`TransactionParams.fee`, `PaymentTransactionBuilder.fee(_:)`), `init`, `params`, `validRounds`,
and the eleven factory names. Everything else new is `internal`: the v42 constants, the surcharge
helpers, `validityWindow(rounds:)`, and the 75-byte envelope estimate.
