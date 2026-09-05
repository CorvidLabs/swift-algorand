---
change: consensus-v42-fee-model-feestrategy-on-every-builder-and-initializer-per-transaction-usage-and-a-group-pooled-fee
artifact: research
---

# Research

## The v42 fee model in go-algorand v5.0.1-stable

- `data/transactions/transaction.go` `feeFactor`: `1e6 + Header.FeeContribution` plus, for
  `appl`, `ApplicationCallTxnFields.feeContribution`; `Header.FeeContribution` is
  `PerByteTxnSurcharge.MulInt(len(Note) - MaxTxnNoteBytes)`, saturating at zero below the tier.
- `data/transactions/application.go` `feeContribution`: `PerByteTxnSurcharge *
  LargeProgramExtraBytes(len(apap) + len(apsu))` with the free size
  `MaxAppTotalProgramLen * (1 + MaxExtraAppProgramPages) = 2048 * 4 = 8192`, plus
  `PerByteTxnSurcharge * (sum(len(apaa)) - MaxAppTotalArgLen)`. `apep` is not read.
- `data/transactions/signedtxn.go` `FeeFactor`: `signatureFeeContribution + Txn.feeFactor`, where
  the signature term is `PQSchemeFeeContribution(scheme)` for a `pqsig` (or a LogicSig's
  `pqsig`) and 0 otherwise. `SummarizeFees` sums `FeeFactor` and `Txn.Fee` over the group and
  adds `logicSigProgramFeeContribution`, which prices `sum(len(lsig.l)) - len(group) * 1000`.
- `config/consensus.go`: `PerByteTxnSurcharge = 100` ("each charged byte adds 0.000100 of min
  fee"), `MaxAbsoluteTxnNoteBytes = 4096`, `MaxAbsoluteTotalArgLen = 16384`,
  `MaxAbsoluteExtraProgramPages = 7`, `PQSchemeFeeContribution(f1) = 2e6`, `MinTxnFee = 1000`.
- `data/basics/overflow.go` `FeeForUsage`: `Mul2div(minFee, usage, 1e6, 1e12)`, exact quotient
  kept, any remainder rounded up once, overflow reported. `ledger/eval/eval.go` `CheckGroupFees`
  calls it with no residue and compares `feesPaid`, after the loop that applies each member.

## What the node reports

`simulate` returns `group-usage` and `group-fees-paid` per group (`handlers.go`
`PreEncodedSimulateTxnGroupResult`, `algod.oas2.json`). Seven probes matched the SDK exactly;
see `testing.md`. Because `CheckGroupFees` runs after apply, an unfunded sender's group fails at
`overspend` whether or not its fees suffice, so `group-usage` is the oracle and `overspend` is
evidence of decode and signature verification only.

## The official SDKs' `suggested` semantics

py-algorand-sdk sets `fee = max(estimate_size() * fee_per_byte, min_fee)` unless `flat_fee`,
where `estimate_size` is the length of the msgpack `SignedTransaction` with a fake signature;
js-algorand-sdk's `estimateSize` is the same envelope. Both hardcode `MIN_TXN_FEE = 1000` as a
named constant and read `min-fee` from parameters when they have them. This change follows that
shape: `.suggested` is `max(minimum, fee * (encode().count + 75))`, and
`AlgorandConsensus.v42.minimumFee` is the named constant.

## Defects in the earlier design, and their resolution

The rejected design pooled a group-wide LogicSig size allowance of 16000 (the v40 cap is per
program; v42 prices bytes beyond 1000 per LogicSig): this model does not price LogicSigs at all
and says so. It saturated a multiply into `MicroAlgos.max`: every multiply and sum here reports
overflow and throws `FeeError.overflow`. It asserted that per-transaction ceilings always clear
the pooled requirement: no such claim is made and the group helper is the authority. It enforced
per-transaction LogicSig argument caps that are pooled and conditional: nothing is enforced;
the absolute maxima are documented as the node's to reject.

## Licence boundary

No fixture was copied from an AGPL-3.0 or unlicensed upstream. The golden payment is the
canonical change's own `pay_min_fee_from_params` vector; the post-quantum key is the post-quantum
change's deterministic stand-in; the live probes use freshly derived throwaway accounts.
