# Lesson bundle — canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference

Material for folding this change's lessons into the affected specs' `context.md`.
Synthesise from what actually happened below; do not restate the change description.

## What this change was

- **Title**: Canonical MessagePack encoding conformance for consensus v42: omit-empty fields, MessagePack booleans, box reference indexes, and grouped transaction IDs
- **Kind**: BugFix
- **Specs**: algorand
- **Paths**: Sources/Algorand, Tests/AlgorandTests, specs/algorand
- **Acceptance**: A 69-vector golden conformance suite, generated from go-algorand v5.0.1-stable's msgp-generated marshaller, asserts byte equality of the encoded transaction and the computed transaction ID. All 15 vectors that fail against the current encoder pass: fee/fv/lv/gen/note/lease/xaid/amt omitted when zero or empty; nonpart and afrz encoded as msgpack bool; box references translated to foreign-app indexes with 0 for the current application; SignedTransaction.id() hashing the grouped encoding. Verified independently against a live consensus v42 TestNet node via /v2/transactions/simulate: each fixed form reaches balance application (HTTP 200) where the current form returns HTTP 400 'At least one signature didn't pass verification'. swift build and swift test remain green on macOS and Linux.

## Evidence

- Verification commit: `8546b6ab64d5f8550fafe6d806573e3e55468c13`
- Base commit: `0d8a85f5c569ac2c9201a8f521ad178354e96f63`
- Verified by: `specsync check --spec algorand`

## From the change's context.md

# Context

## What led here

An audit of this SDK against consensus v42 asked a simple question the existing tests could not
answer: do the bytes we sign match the bytes a node verifies? The encoding tests in
`Tests/AlgorandTests/` assert `encoded.count > 0` or that a substring is present. That passes for a
correct encoder and for a differently-wrong one alike, and the shipped encoder is the second kind.

Reproducing it against a live TestNet node took the question out of the realm of opinion: a payment
with `fee: 0` written explicitly returns `HTTP 400 {"message":"At least one signature didn't pass
verification"}`, while the same payment with `fee` omitted returns `HTTP 200` and reaches balance
application. Full evidence in `research.md`.

## The one thing a future session must not get wrong

**py-algorand-sdk is not a byte oracle. go-algorand's `msgp_gen.go` at the pinned tag is.**

py-algorand-sdk 2.12.0 disagrees with go-algorand v5.0.1-stable in three places, and is wrong in all
three:

| Field | py-algorand-sdk | go-algorand |
|---|---|---|
| `apan` | written unconditionally (`ApplicationCallTxn.dictify`) | omitted when `OnCompletion == 0` |
| `nonpart` | written whenever not `None`, so offline keyreg emits `nonpart: false` | a `false` bool is omitted |
| `lx` | `if self.lease:` is truthy for 32 zero bytes | `Lease == [32]byte{}` is omitted |

Any future "cross-check against the Python SDK" that treats a mismatch as a Swift bug will
reintroduce this defect. The golden vectors record the three divergences inline, per-vector, in
`pySdkEncodedHex` / `pySdkNote`. Read those before changing a byte.

## The mechanism, stated once, correctly

Consensus v42 nodes **do not reject non-canonical wire bytes.** They decode leniently — they will
even coerce a msgpack `uint 1` into a Go `bool` — then **re-encode the transaction canonically** and
verify Ed25519 over `"TX" || canonical_bytes`.

This was proved by decoupling the signing bytes from the transmitted bytes: signing canonical bytes
and transmitting deviant ones returns `HTTP 200` with the signature *passing*. So every omit-empty
violation is a **signing-preimage** bug, not a wire-format bug.

Two earlier diagnoses are **refuted** and must not be revived:

- "go-algorand rejects `nonpart` as a uint because it is a decode type error." It does not. The
  codec coerces it silently. The transaction still dies, at signature verification instead.
- "The node cannot parse our encoding." It can. It parses it, re-encodes it, and finds the signature
  does not match.

Note that the `keyreg_nonparticipating` vector's own `description` string in
`canonical-vectors.json` still carries the refuted wording. Task T3 fixes the prose; the bytes were
always right.

## Things already ruled out

- **Per-transaction-type fixes.** Six `encode(groupID:)` implementations each decide omit-empty
  independently. Nine of twelve header fields happen to be right; the distribution of correctness
  *is* the failure mode. A new transaction type would relitigate the rule and get it wrong in a new
  way. Hence one internal choke point.
- **Changing `MessagePackWriter`.** It is already correct: it sorts keys, and `String.sorted()` is
  byte-order-correct for the lowercase-ASCII field-key alphabet. The omit decision belongs before
  the writer, not inside it.
- **Copying upstream fixtures.** `algorandfoundation/falcon-signatures`' `lsig_address_kat.json` is
  AGPL-3.0, and py-algorand-sdk's vendored `pq_test_data/pq*.json` come from
  `algorandfoundation/algokit-polytest`, which publishes no licence at all. Neither is safe in an MIT
  package. Everything was regenerated from first principles. **Keep it that way.**
- **The prior draft design** at `scratchpad/design-encoding/`. It compiles and is a useful
  *reference* for `TransactionFieldMap` and `AppBoxReference`, but an adversarial review returned
  "needs-revision". Its known defects: it adds a public `rejectVersion` parameter to
  `ApplicationCallTransaction.create(...)`, which go-algorand's `wellFormed` rejects outright
  (`RejectVersion > 0` with `ApplicationID == 0`, and `create` hardcodes `ApplicationID == 0`); its
  `breakingChanges` list is presented as exhaustive but is not; and it proposes far more public API
  than this change needs, including a public `Address.isZero`, a public `AccessReference` family,
  and two new `AlgorandError` cases. Treat it as reference, not specification.

## Deliberate deferrals, and why they are separate changes

Their vectors are recorded outside this suite (`DeferredVectors.swift`, or by name), because test
files are exact-only delivery inputs of the change that wrote them and a follow-up change cannot
edit this suite without reopening this change. Each follow-up adds its own test file.

- **`signed_ed25519_rekeyed_sgnr`.** Needs the `SignedTransaction` envelope rewritten around an
  authorization enum (`sig` / `sgnr` / `msig` / `lsig` / `pqsig`). That is the post-quantum change.
  Related latent defect in the same code: `SignedTransaction.encode()` emits a hard-coded `bin8`
  header and `UInt8(signature.count)`, which **traps the process** for any signature over 255 bytes.
  Unreachable today (Ed25519 is 64 bytes), fatal the moment Falcon-1024's 1538-byte signature
  arrives.
- **`pay_min_fee_from_params`.** Needs the v42 fee model. `TransactionParams.minFee` is decoded from
  algod and then never read: `1000` is baked into 21 initializer defaults plus a stored property on
  `PaymentTransactionBuilder`. The exact v42 formula was derived from the live node and is recorded
  in `research.md` §10 so it does not have to be re-derived.

## The generator's shortcut, which the Swift code must not copy

`gen_vectors.py`'s `_is_empty` treats any all-zero byte string as empty. That is right for Go fixed
arrays (`[32]byte`: `lx`, `gh`, `grp`, `am`, addresses) and **wrong** for Go variable slices
(`[]byte`: `note`, `apap`, `apsu`, box `n`), which omit only on `len == 0`. No current vector
exercises the difference, so the vector bytes are unaffected — but `CanonicalTransactionFields` keeps
`set(_:blob:)` and `set(_:digest:)` as separate setters for exactly this reason. Collapsing them
would silently drop a legitimate all-zero note. In the landed code these are `set(_:blob:)` and
`set(_:digest:)` on `CanonicalTransactionFields`.

## One fidelity gap, recorded rather than fixed

go-algorand tags `snd` and `type` `,required` and writes them even when zero.
`CanonicalTransactionFields.setHeader` writes them through the ordinary omit-empty setters, which
would drop an empty type tag or an all-zero sender. Unreachable in practice, uncovered by any
vector, and cheaper to record than to add a `setRequired` escape hatch for a case that cannot occur.
Revisit if a transaction type ever gains a `,required` field that can legitimately be zero.

## Constraints carried into implementation

- CorvidLabs conventions are mandatory: explicit access control on every declaration, K&R braces,
  4 spaces, 120 columns, no `!` / `try!` / `as!`, async/await only, `Sendable` across isolation
  boundaries, descriptive generic names, doc comments on all public API, MARK sections.
- Public API growth is **zero**. Every new `public` costs a row in a coverage-gated export table in
  `specs/algorand/algorand.spec.md` under `[contract] require_coverage = 100`, so both new types
  (`CanonicalTransactionFields`, `CanonicalBoxReferences`) are `internal` and the table stays at 344
  rows. A prior design proposed 314 new public symbols across four workstreams; a later draft
  proposed one (`AppBoxReference`). The landed answer is none — the caller-facing
  `boxes: [(UInt64, Data)]?` already meant "application ID", and fixing the encoder is the whole fix.
- Byte-identical output must be preserved for transactions carrying no zero or empty field. Those 37
  vectors already match go-algorand exactly. A regression there breaks transactions that work today.

## Working materials

Generated in the session that produced this change, under the scratchpad:

| File | What it is |
|---|---|
| `CanonicalEncodingTests.swift` | The 58-case suite, ready to land |
| `canonical-vectors.json` | The 69 vectors, with per-vector py-algorand-sdk divergence notes |
| `gen_vectors.py` | The generator — go-algorand marshaller semantics reimplemented in Python |
| `live-verification.md` | The raw TestNet transcript behind `research.md` |
| `design-encoding/` | The prior draft design (reference only; see "ruled out" above) |

## Linux test-runner lesson

Do not add fast synchronous tests to an XCTest class in this package and expect Linux CI to
survive: corelibs-xctest has an open lost-wakeup deadlock (swift-corelibs-xctest#504) that a
class of microsecond tests triggers almost every run on 6.0 and 6.1. New suites go on Swift
Testing. A hang with no package frames on the stack and only two threads is this bug, not ours.

## From the change's design.md

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

## From the change's testing.md

# Testing

## The suite

Two files.

`Tests/AlgorandTests/CanonicalBoxReferenceTests.swift` exercises the box-index translation in
isolation — the four rules, the `apfa` append path, and the eight-application limit. It exists
because the encoding vectors cannot reach the append path: both box vectors declare `apfa`
explicitly, so the rule that matters most for a caller who forgets to is untested by them.

`Tests/AlgorandTests/CanonicalEncodingTests.swift` — 51 Swift Testing tests over the canonical
encoding vectors (plus 6 in `CanonicalBoxReferenceTests.swift`; both suites are `@Suite` structs;
57 tests, 21 platform-conditional skips). Vectors for behaviour this change does not make
live are recorded in `DeferredVectors.swift` or by name only:

| Group | Count | What it pins |
|---|---|---|
| Transaction encoding vectors | 52 | Full encoded bytes as a hex literal **and** the base32 transaction ID |
| Atomic group ID | 1 | `2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899` for the golden two-payment group |
| Ed25519 point-decode cases | 13 | `edwards25519.Point.SetBytes` acceptance, which determines the canonical PQ-address salt |
| Post-quantum address cases | 3 | `SHA512_256("PQA" + scheme + salt + publicKey)` derivation |

The data lives in `canonical-vectors.json`; `gen_vectors.py` regenerates it. Both belong beside the
suite so a future session can re-derive rather than trust.

**Every assertion is byte equality against a hex literal.** That is the point. The pre-existing
encoding tests assert `encoded.count > 0` or that some substring is present, which cannot
distinguish a correct encoder from a differently-wrong one — which is exactly how the shipped
encoder passed CI while producing transactions the network rejects.

## Vector coverage by transaction family

| Family | Vectors |
|---|---|
| `pay` (13) | `pay_normal`, `pay_fee_zero`, `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`, `pay_empty_genesis_id`, `pay_zero_amount`, `pay_all_omittable_zero`, `pay_close_remainder_to`, `pay_rekey_to`, `pay_full`, `pay_min_fee_from_params`, `pay_large_fee_uint64` |
| `keyreg` (4) | `keyreg_online`, `keyreg_offline`, `keyreg_nonparticipating`, `keyreg_online_no_stateproof` |
| `axfer` (5) | `axfer_opt_in`, `axfer_transfer`, `axfer_close_to`, `axfer_clawback`, `axfer_zero_asset_id` |
| `acfg` (5) | `acfg_create_minimal`, `acfg_create_full`, `acfg_create_default_frozen_false`, `acfg_reconfigure`, `acfg_destroy` |
| `afrz` (2) | `afrz_freeze`, `afrz_unfreeze` |
| `appl` (15) | `appl_noop_minimal`, `appl_opt_in`, `appl_args`, `appl_accounts_assets_apps`, `appl_box_current_app`, `appl_box_self_app_id`, `appl_box_foreign_app`, `appl_box_empty_name`, `appl_create_with_schemas`, `appl_create_zero_schemas`, `appl_create_extra_pages`, `appl_extra_pages_zero`, `appl_delete`, `appl_kitchen_sink`, `appl_access_list_and_reject_version` |
| `hb` / `stpf` (2) | `hb_heartbeat`, `stpf_state_proof` — not modelled by the SDK; skipped |
| groups (3) | `group_txn0_grouped`, `group_txn1_grouped`, `group_txn0_ungrouped` |
| envelopes (3) | `signed_ed25519_only`, `signed_ed25519_rekeyed_sgnr`, `signed_grouped` |

## Baseline: the 15 failures before the change

Identical on macOS and Linux. Thirteen are in scope; two are deferred.

| Vector | Test case | Why it fails today |
|---|---|---|
| `pay_fee_zero` | `testPayFeeZero` | `fee` written when 0 |
| `pay_first_valid_zero` | `testPayFirstValidZero` | `fv` written when 0 |
| `pay_empty_note` | `testPayEmptyNote` | `note` written when empty |
| `pay_zero_lease` | `testPayZeroLease` | `lx` written when all 32 bytes are zero |
| `pay_empty_genesis_id` | `testPayEmptyGenesisId` | `gen` written when `""` |
| `pay_all_omittable_zero` | `testPayAllOmittableZero` | all of the above compounded; correct answer is a 129-byte five-entry map |
| `keyreg_nonparticipating` | `testKeyregNonparticipating` | `nonpart` written as `uint 1` (`0x01`) not `bool` (`0xC3`) |
| `axfer_zero_asset_id` | `testAxferZeroAssetId` | `xaid` written when 0 |
| `appl_box_self_app_id` | `testApplBoxSelfAppId` | box on the called app writes `i` = the raw app ID |
| `appl_box_foreign_app` | `testApplBoxForeignApp` | `i` is the raw app ID, not the 1-based `apfa` index |
| `appl_box_empty_name` | `testApplBoxEmptyName` | `n` written when empty; should leave an empty map |
| `appl_kitchen_sink` | `testApplKitchenSink` | box index translation, compounded with the header rules |
| `group_txn0_grouped` | `testSignedGroupedTransactionReportsGroupedID` | `SignedTransaction.id()` re-encodes with `groupID: nil` and reports an ID that does not exist on chain |
| `pay_min_fee_from_params` | `testBuilderDerivesFeeFromSuggestedParameters` | **deferred** — v42 fee model |
| `signed_ed25519_rekeyed_sgnr` | `testRekeyedEnvelopeCarriesSgnr` | **deferred** — `SignedTransaction` envelope rewrite |

## Deferred vectors

Test files are exact-only delivery inputs of the change that wrote them: a later change cannot
edit this suite without reopening this change. So this suite contains no forward-looking
placeholders. The `pay_min_fee_from_params` vector (fee model) lives in `DeferredVectors.swift`;
the rekeyed-`sgnr` and post-quantum envelope vectors are carried byte-exact by the envelope
change's own suite; `appl_access_list_and_reject_version`, `hb_heartbeat` and `stpf_state_proof`
are recorded by name, their bytes in the generator. Each follow-up change adds its own test file.

## Why Swift Testing, and what Linux proves

The suites were first written for XCTest and hung the Linux process. The cause is an open
lost-wakeup deadlock in swift-corelibs-xctest (#504) that microsecond-fast synchronous tests
trigger almost every run under Docker Desktop on 6.0 and 6.1; research.md has the backtrace and
bisection. Swift Testing has no `XCTWaiter`/run-loop in its path and needs no manifest change.

Linux acceptance for this change is therefore the ported suites in isolation:
`CI=true swift test --disable-xctest` (the `--testing-library` flag is a usage error on 6.0/6.1
SwiftPM) — 5/5 clean runs on swift:6.0-jammy and 5/5 on swift:6.1-jammy with the earlier 65-test
shape of this suite; the restructured 57-test shape is re-verified on Linux before finalize. End-to-end `CI=true swift test` on Linux still hangs locally, 5/5, always inside a
pre-existing XCTest case (`AccountTests`, `AssetManagementTests`, `AtomicTransactionGroupTests`,
`IntegrationTests`, `ProofOfWorkTest` — never a Canonical test). That exposure predates this
change, is byte-for-byte unchanged by it, and has passed GitHub's x86_64 ubuntu job repeatedly;
migrating the legacy suite to Swift Testing is a separate change.

Four vectors named by placeholder tests (`appl_access_list_and_reject_version`, `hb_heartbeat`,
`stpf_state_proof`, and `signed_grouped`'s envelope bytes) have their bytes only in
`canonical-vectors.json`, not yet transcribed into Swift; copy them in when those tests go live.

- **`signed_ed25519_rekeyed_sgnr`.** The correct envelope for a rekeyed account is a three-key map
  `{sgnr, sig, txn}` (280 bytes, opening `83 a473676e72 c420 …`). `SignedTransaction.encode()`
  hand-emits a literal `0x82` two-key map and cannot express it at all. Fixing it means replacing
  the envelope with an authorization enum covering `sig` / `sgnr` / `msig` / `lsig` / `pqsig` —
  which is the post-quantum change, and is separate.
- **`pay_min_fee_from_params`.** The builder's default fee is a hard-coded `1000`, baked into 21
  initializer defaults plus a stored property on `PaymentTransactionBuilder`.
  `TransactionParams.minFee` is decoded from algod and then never read, so a network whose minimum
  fee is not 1000 silently underpays. Fixing it means adopting the v42 fee model (`research.md`
  §10), which is a separate change.

## Pre-existing skips, unchanged by this change

| Test | Reason |
|---|---|
| `testEnvelopeSurvivesSignaturesLongerThan255Bytes` | `SignedTransaction.encode()` emits a hard-coded `bin8` header then `UInt8(signature.count)`. A 1538-byte Falcon-1024 signature **traps the process** rather than throwing, so it cannot be asserted in-process. Belongs to the envelope rewrite |
| `testPostQuantumAddressDerivationIsNotImplemented` | No PQ address derivation in the SDK |
| `testPostQuantumSignedEnvelopeIsNotImplemented` | No `pqsig` envelope in the SDK |
| `testAccessListAndRejectVersionAreNotImplemented` | v42 `al` / `aprv` fields not modelled |
| `testHeartbeatTransactionIsNotImplemented` | No `hb` transaction type |
| `testStateProofTransactionIsNotImplemented` | No `stpf` transaction type |
| `testSignedEnvelopeIsByteExactOnDeterministicBackends` | **macOS only.** CryptoKit randomizes the Ed25519 nonce, so raw signature bytes are not reproducible on Darwin. Runs and passes on Linux, where swift-crypto's Ed25519 is deterministic — this is the entire macOS/Linux count difference |

## Results

| Platform | Before | After (target) |
|---|---|---|
| macOS (`swift test`) | 36 pass / 15 fail / 7 skip | 49 pass / 0 fail / 9 skip |
| Linux (Docker `swift:6.0-jammy`) | 37 pass / 15 fail / 6 skip | 50 pass / 0 fail / 8 skip |

58 cases on both platforms. The failing set is identical on both — this is an encoding defect, not a
platform defect.

## Independent verification: the live node

The vectors say the SDK agrees with a reimplementation of go-algorand's marshaller. Only the network
can say the SDK agrees with go-algorand. For each of the 13 fixed vectors, the new bytes go to
`POST https://testnet-api.algonode.cloud/v2/transactions/simulate`:

- **Pass criterion:** `HTTP 200` and execution reaches balance application — for an unfunded
  throwaway sender that surfaces as `failure-message: "transaction …: overspend (account …)"`, which
  is *past* signature verification.
- **The control it replaces:** the same transaction built by the pre-change encoder returns
  `HTTP 400 {"message":"At least one signature didn't pass verification"}`.
- **Box vectors additionally:** `HTTP 200` with **no** `failure-message`, where the pre-change form
  returns `HTTP 200` carrying `tx.Boxes[0].Index is <N>. Exceeds len(tx.ForeignApps)`. A status-code
  check alone would miss this, so the assertion must read `failure-message`.

Constraints on this lane: `GET` and `POST /v2/transactions/simulate` only. `POST /v2/transactions`
is never called, no funds move, nothing lands on chain. It runs outside the deterministic
pull-request lane, consistent with existing invariant 5 in the canonical spec.

## Regression fence

The 37 vectors passing before the change must pass after it, byte-identical. They are the
transactions that carry no zero or empty field — the shape of every working transaction in
production. A regression there breaks transactions that work today, which is strictly worse than
the bug being fixed.

## Requirement evidence

All tests below live in `Tests/AlgorandTests/CanonicalEncodingTests.swift` unless marked `[Box]`
(`Tests/AlgorandTests/CanonicalBoxReferenceTests.swift`). Every listed test asserts byte equality
against a go-algorand-derived golden vector or a live-node-confirmed behaviour.

| Requirement | Evidence |
|---|---|
| REQ-algorand-002 | `testPayNormal`, `testPayFull`, `testKeyregOnline`, `testAxferTransfer`, `testAcfgCreateFull`, `testAfrzFreeze`, `testApplKitchenSink` — byte-exact encodings and transaction IDs; the 69-vector suite as a whole. Live: fee=0 / empty note / zero lease / empty gen payment reaches `overspend` (signature verified) on TestNet v42. |
| REQ-algorand-006 | `testApplBoxCurrentApp`, `testApplBoxSelfAppId`, `testApplBoxForeignApp`, `testApplBoxAppendPath`, `testApplBoxEmptyName`, `testApplKitchenSink`, `testApplAccountsAssetsApps` — boxes named by owning application ID encode as `apfa` slot indexes. |
| REQ-algorand-007 | `testKeyregNonparticipating` (`nonpart` = `0xC3`), `testKeyregOffline` (`nonpart` omitted), `testKeyregOnline`, `testKeyregOnlineNoStateproof`. Live: nonparticipating keyreg reaches `overspend` where the uint form returned HTTP 400. |
| REQ-algorand-013 | `testPayFeeZero`, `testPayFirstValidZero`, `testPayEmptyNote`, `testPayZeroLease`, `testPayEmptyGenesisId`, `testPayZeroAmount`, `testPayAllOmittableZero`, `testAxferZeroAssetId`, `testApplExtraPagesZero`, `testApplCreateZeroSchemas`, `testAcfgCreateDefaultFrozenFalse`. |
| REQ-algorand-014 | `testKeyregNonparticipating`, `testKeyregOffline`, `testAfrzFreeze`, `testAfrzUnfreeze`, `testAcfgCreateDefaultFrozenFalse` — booleans written as `0xC3`, omitted when false, never `0xC2` or an integer. |
| REQ-algorand-015 | `testApplBoxCurrentApp`, `testApplBoxSelfAppId`, `testApplBoxForeignApp`, `testApplBoxAppendPath`, `testApplBoxEmptyName`; `[Box]` `testUndeclaredApplicationIsAppendedToForeignApps`, `testRepeatedReferencesShareOneForeignAppSlot`, `testCurrentApplicationNeverExtendsForeignApps`, `testEncodedTransactionCarriesTheAppendedForeignApp`, `testUnresolvableReferenceThrows`, `testEncodingPropagatesTheUnresolvableReferenceError`. Live: `i` = raw app ID rejected with `Exceeds len(tx.ForeignApps)`; index form accepted. |
| REQ-algorand-016 | `testGroupedAndUngroupedTransactionIDsDiffer`, `testSignedGroupedTransactionReportsGroupedID`, `testGroupedTransactionZeroEncoding`, `testGroupedTransactionOneEncoding`, `testGroupIDIsExactlyTheGoldenValue`, `testGroupIDIsStableAcrossConstruction`. Live: the node's own ID for group member 0 equals `SignedTransaction.id()`. |
| REQ-algorand-017 | `testPayNormal`, `testPayFull`, `testAcfgCreateFull`, `testApplKitchenSink` — unchanged golden bytes for transactions with no zero/empty field; independently diffed pre- vs post-change (clone at 0d8a85f) with identical hex and identical node-reported transaction ID. Single choke point: every `encode(groupID:)` routes through `CanonicalTransactionFields`. |
| REQ-algorand-018 | Suite provenance in the `CanonicalEncodingTests` header: vectors generated from go-algorand v5.0.1-stable `msgp_gen.go` semantics, cross-checked against py-algorand-sdk 2.12.0 with its three deviations catalogued; AGPL-3.0 Falcon/lsig fixtures deliberately not copied. |

## Where these lessons go

- `specs/algorand/context.md`
