---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: design
---

# Design

## The shape of the defect

`SignedTransaction.sign` hashes exactly what `Transaction.encode(groupID:)` produced:

```swift
let encoded = try transaction.encode(groupID: groupID)
let prefixed = Data("TX".utf8) + encoded
let signature = try account.sign(prefixed)
```

A consensus v42 node does the opposite: it decodes the submitted bytes leniently, **re-encodes the
transaction canonically** with msgp `omitempty`, and verifies Ed25519 over `"TX" || canonical`
(proved in `research.md` §3). The two preimages must agree byte-for-byte. Any field this SDK writes
that go-algorand would have omitted makes the signature unverifiable, and the node answers
`HTTP 400 {"message":"At least one signature didn't pass verification"}`.

So this is not a wire-format bug. It is a **signing-preimage** bug, and the encoder is the signer.

## Why omit-empty belongs in one place

Today each transaction type builds its own `[String: MessagePackValue]` dictionary and decides,
inline and independently, whether a field is present. Six `encode(groupID:)` implementations across
four files repeat the header block:

```swift
map["fee"] = .uint(fee.value)      // written even when 0          <- defect
map["fv"]  = .uint(firstValid)     // written even when 0          <- defect
map["gen"] = .string(genesisID)    // written even when ""         <- defect
map["lv"]  = .uint(lastValid)
if let note { map["note"] = .binary(note) }    // written even when empty      <- defect
if let lease { map["lx"] = .binary(lease) }    // written even when 32 zeros   <- defect
```

Some sites already got it right by hand (`amt`, `apid`, `apan`, `apep`, `afrz`, `apar.df`,
`apar.dc`); most did not. That distribution *is* the failure mode: a rule enforced in twelve places
holds in nine of them. Every future transaction type — heartbeat, state proof, the v42 `al` access
list — would relitigate the same rule and get it wrong in a new way.

The fix is one internal choke point, `CanonicalTransactionFields`, through which every field passes.
Its setters are named for the **Go type** of the field, because the omit condition is a property of
that type, not of the field:

| Setter | Go type it mirrors | Omits when |
|---|---|---|
| `set(_:uint:)` | `uint64`, `uint32`, `basics.Round`, `AssetIndex`, `AppIndex`, `MicroAlgos` | `== 0` |
| `set(_:bool:)` | `bool` | `== false`; otherwise writes MessagePack `0xC3` |
| `set(_:string:)` | `string` | empty |
| `set(_:blob:)` | `[]byte` (variable slice) | `nil` or `count == 0` — an all-zero non-empty slice is **kept** |
| `set(_:digest:)` | `[N]byte` (fixed array) | `nil`, empty, or every byte zero |
| `set(_:address:)` | `basics.Address` | `nil` or the all-zero address |
| `set(_:array:)` | slice under `omitemptyarray` | empty; elements are never pruned |
| `set(_:map:)` | nested struct under `omitempty` | the nested `CanonicalTransactionFields` has no surviving field |

`setHeader(type:sender:fee:firstValid:lastValid:genesisID:genesisHash:note:lease:rekeyTo:groupID:)`
installs go-algorand's shared `transactions.Header` in one call. Routing all transaction types
through it is what keeps `fee`, `fv`, `lv`, `gen`, `gh`, `grp`, `lx`, `note`, and `rekey` consistent
between them — the header was where nine of the twelve defects lived.

The `blob:` / `digest:` split is deliberate, and is the one place where the Python vector generator
takes a shortcut the Swift code must not copy (`research.md` §8): go-algorand omits a fixed
`[32]byte` when it is all zero, but keeps a variable `[]byte` of the same content, because a Go
slice can distinguish "absent" from "thirty-two zero bytes" and a Go array cannot. Using
`digest:` for `note` would silently drop a legitimate all-zero note.

`set(_:map:)` takes a `CanonicalTransactionFields`, not a dictionary, so nested structures (`apar`,
`apgs`, `apls`, each `apbx` entry) obey the same rules by construction and an all-zero `StateSchema`
disappears rather than encoding as `{}`.

`MessagePackWriter` is **unchanged**. It already sorts keys and already emits `0xC3`/`0xC2` for
`.bool`. Its `String.sorted()` ordering is byte-order-correct for the field-key alphabet, which is
pure lowercase ASCII. The omit decision happens strictly before the writer sees a map, so the writer
keeps its single responsibility.

### Known fidelity gap: the two `,required` fields

go-algorand tags `Header.Sender` (`snd`) and `Transaction.Type` (`type`) `,required`, so it writes
them even when zero. `setHeader` writes them through `set(_:address:)` and `set(_:string:)`, which
would omit them. The divergence is unreachable in practice — no valid transaction has an empty type
tag or the all-zero sender — and no golden vector exercises it. It is recorded here rather than
fixed, because a `setRequired` escape hatch is API surface for a case that cannot occur. See
`openDecisions`.

## Boolean fields

`nonpart` is currently written as `.uint(1)`. go-algorand writes it with `msgp.AppendBool` and reads
it with `msgp.ReadBoolBytes`; the canonical byte is `0xC3`, and a `false` bool is omitted entirely.
`afrz` and `apar.df` are the same shape and already correct in the current code — `set(_:bool:)` is
what makes all three correct *by construction* rather than by three independent hand-written guards.

There is no `.bool(false)` path. A `false` bool is never written.

## Box references

The `i` slot inside an `apbx` entry is a **slot index**, not an application ID (`research.md` §5).
The current encoder writes the caller's raw application ID there, which the node rejects with
`tx.Boxes[0].Index is <N>. Exceeds len(tx.ForeignApps)` — delivered as an HTTP 200 simulate result
carrying a `failure-message`, so a status-code-only client never notices.

`CanonicalBoxReferences` performs the translation at encode time. It is `internal`, and the public
`boxes: [(UInt64, Data)]?` parameter is **unchanged**: the caller keeps naming boxes by owning
application ID, which is the space callers think in, and which is what the tuple's documentation
already claimed (`// (app_id, box_name)`). The bug was that the encoder wrote that ID straight into
`i`; the type was never wrong, only its handling.

Translation rule, applied per box:

1. `applicationID == 0` → wire index `0`, `i` omitted (0 is the omit-empty zero).
2. `applicationID == apid`, the application being called → wire index `0`, `i` omitted.
   Verified: `appl_box_self_app_id` encodes `81 a16e c407 "counter"` — `i` absent.
3. Otherwise the wire index is the 1-based position in `apfa`.
   Verified: `appl_box_foreign_app` with `apfa = [987654321, 123456789]` encodes
   `92 82 a169 01 a16e c405 "alpha"  82 a169 02 a16e c404 "beta"` — indexes 1 and 2, and the raw
   ids `ce3ade68b1` / `ce075bcd15` appear only inside `apfa`, never inside `apbx`.
4. When the application is in neither position it is **appended to `apfa`**, and the resulting
   1-based position is used. `CanonicalBoxReferences` returns both the translated references and the
   extended `foreignApplications`, so `apfa` and `apbx` are always encoded from the same array.
   Appending past `maximumForeignApplications` (8, from consensus v28 onward) throws
   `AlgorandError.invalidTransaction`.
5. `n` is omitted when the name is empty, which can leave the entry as an empty map `80`.
   Verified: `appl_box_empty_name` encodes `apbx: 91 80`. go-algorand reads that as a request for
   one more unit of box read/write quota rather than as a named box.

Rule 4 is the one judgement call. py-algorand-sdk and js-algorand-sdk both *throw* here
(`InvalidForeignIndexError` / "Box app ID not in foreign apps"). Appending is chosen instead because
the caller named a box on an application, and a box reference is only resolvable through `apfa`;
refusing would mean rejecting a request the SDK can satisfy exactly. The cost — `apfa` growing
beyond what the caller wrote — is bounded by the client-side limit in rule 4, which fails loudly
rather than letting the node reject the transaction later.

No golden vector exercises rule 4, because both box vectors supply `apfa` explicitly. One should be
added (task T14).

## Grouped transaction identity

```swift
public func id() throws -> String {
    try transaction.id()          // Transaction.id() re-encodes with groupID: nil
}
```

`SignedTransaction` holds the `groupID` it signed with, then throws it away when reporting the ID.
For a grouped transaction the reported string is the hash of a *different* encoding than the one
signed and submitted — an ID that does not exist on chain, so `waitForConfirmation` on it can never
succeed.

The fix is local: `SignedTransaction.id()` hashes `transaction.encode(groupID: groupID)` — the same
bytes `sign` hashed. `Transaction.id()` keeps its current meaning (the ungrouped ID), because a bare
transaction genuinely does not know its group, and because `AtomicTransactionGroup.computeGroupID`
*requires* the ungrouped encoding: go-algorand builds `TxGroup.TxGroupHashes` from each member's
ungrouped `Txn.ID()`. That is why `testGroupIDIsExactlyTheGoldenValue` already passes and must keep
passing.

## Public API: what changes, what does not

**No new public symbol. No changed public signature.** The SpecSync export table stays at **344
rows**, and the change is fully source-compatible.

Both new types are `internal`:

| Type | File | Why internal |
|---|---|---|
| `CanonicalTransactionFields` | `Sources/Algorand/CanonicalTransactionFields.swift` | An encoder implementation detail. No caller assembles a transaction field map by hand |
| `CanonicalBoxReferences` | `Sources/Algorand/CanonicalBoxReferences.swift` | A translation applied during `encode`. Callers keep naming boxes by application ID |

**Rejected alternative: a public `AppBoxReference` struct.** A named `public struct` replacing
`[(UInt64, Data)]?` would document the app-ID-vs-index distinction at the call site and could conform
to `Hashable`. It was rejected because it costs a public export row, breaks every call site's source,
and buys nothing the tuple's existing `// (app_id, box_name)` contract did not already promise —
the tuple's semantics were always "application ID"; only the encoder disagreed. Fixing the encoder
is the whole fix. It can be revisited as ergonomics work, separately, without another wire change.

**Observable behaviour that does change, source-compatibly.**

- Encoded bytes, and therefore transaction IDs, change for any transaction that carried a zero or
  empty field. Transactions carrying none are byte-identical.
- `boxes:` entries whose `UInt64` is a foreign application ID now produce a *working* transaction
  instead of one the node rejects. `apfa` may gain an entry the caller did not write.
- `SignedTransaction.id()` returns the grouped ID for a grouped transaction.

**Does not change.**

- `MessagePackWriter`, `MessagePackValue`, `Transaction`, `SignedTransaction.sign`,
  `SignedTransaction.encode`, `AtomicTransactionGroup`, `AlgorandError`, every client, response
  model, and builder.
- `Transaction.id()` still means the ungrouped ID.
- `AssetConfigTransaction.strictEmptyAddressChecking` keeps its current meaning. It guards against
  *accidentally clearing* a manager/reserve/freeze/clawback role. Under canonical encoding an
  explicitly-zero role address is now omitted rather than written as 32 zero bytes; on chain both
  forms mean "clear this role permanently", so the guard is as necessary as before and is untouched.
- No new `AlgorandError` case. The foreign-application limit throws the existing
  `.invalidTransaction`; writer failures throw the existing `.encodingError`.

**Deliberately not added**, though a prior draft proposed them: a public `AppBoxReference`, a public
`Address.isZero`, a public `rejectVersion` parameter on `ApplicationCallTransaction.create(...)`
(go-algorand's `wellFormed` rejects `RejectVersion > 0` when `ApplicationID == 0`, which `create`
hardcodes, so the parameter would be unusable there), public `AccessReference` / `al` support, a
public `TransactionHeader`, and public heartbeat or state-proof transaction types.

## Byte-identical preservation

The 37 golden vectors that pass today were byte-diffed against go-algorand and match exactly. Those
are transactions carrying no zero or empty field — the shape of every working transaction in
production. The choke point must not perturb them: `set(_:uint:)` on a non-zero fee writes the same
`.uint`, key ordering is still `MessagePackWriter`'s, and integer width selection is unchanged. The
suite lands before the encoder change precisely so this is measured rather than asserted.

## New and touched files

| Path | Status | Access |
|---|---|---|
| `Sources/Algorand/CanonicalTransactionFields.swift` | new | `internal` throughout |
| `Sources/Algorand/CanonicalBoxReferences.swift` | new | `internal` throughout |
| `Sources/Algorand/PaymentTransaction.swift` | edit | `encode` routed through the choke point |
| `Sources/Algorand/KeyRegistrationTransaction.swift` | edit | same; `nonpart` becomes `set("nonpart", bool:)` |
| `Sources/Algorand/AssetTransaction.swift` | edit | same, all five asset transaction types plus `apar` |
| `Sources/Algorand/ApplicationTransaction.swift` | edit | same; box index translation |
| `Sources/Algorand/Transaction.swift` | edit | doc comment distinguishing ungrouped `id()` |
| `Sources/Algorand/SignedTransaction.swift` | edit | `id()` hashes the grouped encoding |
| `Tests/AlgorandTests/CanonicalEncodingTests.swift` | new | 58 cases, byte equality against hex literals |
| `Tests/AlgorandTests/CanonicalBoxReferenceTests.swift` | new | the translation rules in isolation, including the append path |
