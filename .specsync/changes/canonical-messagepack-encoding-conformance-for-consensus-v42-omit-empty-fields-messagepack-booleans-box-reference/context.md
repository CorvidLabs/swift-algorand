---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: context
---

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
