---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: docs
---

# Docs

## The headline for users

> Transactions built by earlier versions of this SDK are rejected by Algorand consensus v42 nodes
> whenever they carry a zero or empty field. This release makes the encoding canonical. **The
> transaction ID of any such transaction changes** — the old ID never existed on chain.

That second sentence is the part users must not miss. A caller who logged, stored, or displayed a
transaction ID from a previous version holds a value no node will ever confirm.

## Compatibility

**The change is fully source-compatible.** No public type, signature, or parameter changes, and no
new public symbol is added. Nothing needs migrating; recompiling is enough.

That makes the *behavioural* changes the whole documentation burden, because they are silent.

| Change | Kind |
|---|---|
| Canonical omit-empty across all transaction types | Behavioural — encoded bytes and transaction IDs change |
| `nonpart` as MessagePack bool | Behavioural — nonparticipating keyreg now works at all. `afrz` and `apar.df` were already bools at baseline; their bytes and IDs are unchanged |
| Box references translated to `apfa` indexes | Behavioural — box references now work at all; `apfa` may gain an entry |
| `SignedTransaction.id()` returns the grouped ID | Behavioural — a previously wrong value becomes right |

## Behavioural changes to document

1. **Transaction IDs change** for any transaction that previously carried a zero or empty `fee`,
   `fv`, `lv`, `gen`, `note`, `lx`, `xaid`, `caid`, `aamt`, or a zero `close` / `rekey` / `aclose` /
   `asnd` / `fadd` address, or a zero-schema `apgs` / `apls`. Transactions carrying none of those
   keep exactly their current bytes and ID.
2. **`SignedTransaction.id()` on a grouped transaction** now returns the ID of the bytes actually
   signed and submitted. It previously returned the ungrouped ID — a value that never appears on
   chain, so `waitForConfirmation` on it could not succeed. `Transaction.id()` still returns the
   ungrouped ID, and `AtomicTransactionGroup.groupID` is unchanged (it is derived from ungrouped
   member encodings by definition).
3. **Nonparticipating key registration now works.** It could not previously be accepted by any node.
4. **Box references now work.** They could not previously be accepted by any node.

## The one silent semantic change worth calling out loudly

`ApplicationCallTransaction.boxes` keeps its type, `[(UInt64, Data)]?`, and keeps its documented
meaning, `(app_id, box_name)`. What changes is that the encoder now honours that meaning.

```swift
// Unchanged call site — now produces a transaction the network accepts.
let call = ApplicationCallTransaction.call(
    sender: sender,
    applicationID: appID,
    boxes: [
        (0, Data("counter".utf8)),          // a box on the application being called
        (otherAppID, Data("shared".utf8))   // a box on another application
    ],
    firstValid: params.firstRound,
    lastValid: params.firstRound + 1000,
    genesisID: params.genesisID,
    genesisHash: params.genesisHash
)
```

Previously the `UInt64` was written straight into the wire field `i`, which is a **slot index into
`apfa`**, not an application ID — so every node answered
`tx.Boxes[0].Index is <N>. Exceeds len(tx.ForeignApps)`. Now it is translated: `0` and the called
application's own ID both become index `0`; any other application becomes its 1-based position in
`apfa`, **and is appended to `apfa` if the caller did not declare it**.

Two consequences to document:

- The encoded `apfa` array may contain an application the caller did not pass in `foreignApps`.
- A transaction that would need more than eight foreign applications now throws
  `AlgorandError.invalidTransaction` at encode time rather than being rejected by the node.

## Where documentation changes

| Surface | Change |
|---|---|
| DocC symbol docs | Update `ApplicationCallTransaction.boxes` to state that the `UInt64` is the owning application ID and is translated to an `apfa` slot at encode time, appending to `apfa` when needed. Update `SignedTransaction.id()` to distinguish it from `Transaction.id()` |
| `Sources/Algorand/Algorand.docc/Algorand.md` | No new symbol to add to a topic group. Consider an article on canonical encoding if one is wanted; not required |
| `Sources/Algorand/Algorand.docc/GettingStarted.md` | No change required — it does not show box references |
| `README.md` | No change required — verified it does not mention boxes, `nonpart`, or MessagePack |
| `documentation/GETTING_STARTED.md`, `documentation/QUICKSTART.md` | No change required — verified, same |
| Release notes (`fledge changelog`) | The headline above, the transaction-ID warning, and the box-reference behaviour change. State plainly that no code changes are needed |

## What the docs must NOT say

Do not describe this as "matching the Python SDK". py-algorand-sdk deviates from go-algorand on
`apan`, `nonpart`, and `lx` (`research.md` §7); this SDK deliberately does not match it. The
documented authority is go-algorand v5.0.1-stable.

Do not describe the previous behaviour as "a wire-format incompatibility". Nodes parse the old bytes
fine. The defect is that the SDK signed a preimage the node does not reconstruct. Getting this wrong
in the release notes invites the wrong fix later.
