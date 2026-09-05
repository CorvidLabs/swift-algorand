---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: requirements
---

# Requirements

Six new requirements, continuing `specs/algorand/requirements.md` from `REQ-algorand-012`. Two
existing requirements are currently **violated by the shipped code**; this change is what makes them
true, and their acceptance criteria are tightened accordingly.

## Existing requirements this change repairs

### REQ-algorand-002 — currently VIOLATED

> `MicroAlgos`, `SHA512_256`, secure randomness, and MessagePack encoding SHALL preserve
> protocol-compatible numeric, hash, random-byte, and **canonical wire representations**.

The wire representation is not canonical. `fee`, `fv`, `gen`, `note`, and `lx` are emitted when
zero or empty, and a consensus v42 node rejects the resulting signature
(`research.md` §2). The requirement's acceptance criterion — "transaction encoding tests pass" —
was satisfiable by tests that assert only `encoded.count > 0`, which cannot distinguish a correct
encoder from a differently-wrong one. Amended criterion:

> Amount arithmetic and conversion, official hash vectors, generated randomness use, and the
> canonical golden-vector suite pass, the latter by **byte equality** against vectors derived from
> go-algorand v5.0.1-stable.

### REQ-algorand-007 — currently VIOLATED

> Key-registration construction SHALL preserve online, offline, and nonparticipating vote,
> selection, dilution, state-proof, and **participation fields**.

`KeyRegistrationTransaction.encode` writes `nonpart` as MessagePack `uint 1` (`0x01`). go-algorand
writes and reads it as a bool (`0xC3`). A nonparticipating key registration built by this SDK can
never be accepted (`research.md` §3, CLAIM 2). Amended criterion:

> Existing online, offline, nonparticipating, and signing tests pass, and the
> `keyreg_nonparticipating` golden vector matches byte-for-byte, including `nonpart` as a
> MessagePack bool.

## New requirements

### REQ-algorand-013

Transaction encoding SHALL omit every field that holds its go-algorand zero value, following the
`_struct codec:",omitempty,omitemptyarray"` semantics of go-algorand v5.0.1-stable: unsigned
integers when `0`, strings when empty, variable-length byte slices when `len == 0`, fixed-width byte
arrays and addresses when every byte is zero, arrays when empty, and nested structures when
recursively empty. `snd` and `type` are the only transaction fields exempt, because go-algorand tags
them `,required`.

Acceptance Criteria
- The `pay_fee_zero`, `pay_first_valid_zero`, `pay_empty_note`, `pay_zero_lease`,
  `pay_empty_genesis_id`, `pay_all_omittable_zero`, and `axfer_zero_asset_id` vectors match
  byte-for-byte and produce the golden transaction ID.
- `pay_empty_note` and `pay_zero_lease` produce the same 166-byte encoding and the same transaction
  ID `O5CHKYIB3T7YBA4KATYKNGWU5AB3NTN2TZ2E2IJUIZXRMNPINM2Q` as `pay_normal`, because the empty field
  vanishes entirely.
- `pay_all_omittable_zero` encodes to 129 bytes, a five-entry map carrying only `gh`, `lv`, `rcv`,
  `snd`, `type`.
- A variable-length byte field whose content is all zeros but non-empty is retained, not omitted.

### REQ-algorand-014

Boolean transaction fields — `nonpart`, `afrz`, and `apar.df` — SHALL be encoded as a MessagePack
boolean (`0xC3`) and SHALL be omitted entirely when false. No boolean field is ever encoded as an
integer, and `0xC2` (false) is never written.

Acceptance Criteria
- `keyreg_nonparticipating` encodes `a76e6f6e70617274 c3` and matches its 131-byte golden encoding.
- `keyreg_offline` omits `nonpart` entirely rather than writing `false`.
- `afrz_freeze` writes `afrz` as `0xC3`; `afrz_unfreeze` omits it.
- `acfg_create_default_frozen_false` omits `apar.df`.

### REQ-algorand-015

An application call's `apbx` entries SHALL carry a foreign-application **slot index**, never an
application ID. The index SHALL be `0` when the box belongs to the application the transaction calls
(whether the caller wrote `0` or the application's own ID), and otherwise the 1-based position of
that application in `apfa`. An application named by a box reference but absent from `apfa` SHALL be
appended to `apfa` so the index resolves, and SHALL fail with `AlgorandError.invalidTransaction`
when that would exceed the eight-foreign-application limit. The box name `n` SHALL be omitted when
empty. The caller-facing `boxes: [(UInt64, Data)]?` parameter continues to name boxes by owning
application ID; the translation is internal to encoding.

Acceptance Criteria
- `appl_box_current_app` and `appl_box_self_app_id` both omit `i`.
- `appl_box_foreign_app` encodes `i` as `1` and `2` for `apfa = [987654321, 123456789]`, and the
  raw application-ID byte sequences `ce3ade68b1` and `ce075bcd15` appear only inside `apfa`, never
  inside `apbx`.
- `appl_box_empty_name` encodes `apbx` as `91 80` — one entry, an empty map.
- `appl_kitchen_sink` matches its 401-byte golden encoding.
- A box naming an application absent from `apfa` encodes with that application appended to `apfa`
  and an index equal to its new 1-based position; a ninth foreign application throws
  `AlgorandError.invalidTransaction`.

### REQ-algorand-016

`SignedTransaction.id()` SHALL return the identifier of the bytes that were signed. For a
transaction signed as part of an atomic group that means the encoding **including** `grp`.
`Transaction.id()` SHALL continue to return the ungrouped identifier, because
`AtomicTransactionGroup` derives the group ID from each member's ungrouped encoding.

Acceptance Criteria
- `group_txn0_grouped` reports `3ZFBH32KQJVFCXLXVRCONWKYXL5R5EENIRHKURR3LFL4UGPD3CFQ` through
  `SignedTransaction.id()`.
- `AtomicTransactionGroup.groupID` remains
  `2e17dd6e388e7b5a34dc844cf3555711687f06b9633796ccaf082239247fd899` for the golden two-payment
  group, and is stable across repeated construction.
- The grouped and ungrouped identifiers of the same transaction differ.

### REQ-algorand-017

Transactions that carry no zero-valued or empty field SHALL encode to byte-identical output before
and after this change. The omit-empty rules SHALL be enforced at a single internal choke point
through which every transaction field passes, so that a new transaction type cannot reintroduce the
defect by omission.

Acceptance Criteria
- All 37 golden vectors that pass against the pre-change encoder still pass, unchanged, against the
  post-change encoder.
- No `encode(groupID:)` implementation assigns directly into a `[String: MessagePackValue]`; every
  field is written through `CanonicalTransactionFields`, and every transaction type installs its
  shared header through the one `setHeader(...)` call.
- `MessagePackWriter` and `MessagePackValue` are unchanged.

### REQ-algorand-018

The canonical encoder SHALL be verified by byte-equality golden vectors whose authority is
go-algorand v5.0.1-stable's msgp-generated marshaller. py-algorand-sdk SHALL NOT be treated as a
byte oracle: it deviates from go-algorand on `apan`, `nonpart`, and `lx`, and matching it would
reintroduce the defect. No vector or fixture may be copied from an AGPL-3.0 or unlicensed upstream
into this MIT package.

Acceptance Criteria
- The suite asserts encoded bytes and transaction ID against hex literals, not shape or length.
- The three py-algorand-sdk deviations are recorded in the suite's own documentation alongside the
  vectors that expose them.
- No file under `Tests/` originates in `algorandfoundation/falcon-signatures` or
  `algorandfoundation/algokit-polytest`.

## Constraints

- Public API growth is **zero**. Both new types are `internal`, the SpecSync export table stays at
  344 rows, and the change is source-compatible.
- The v42 fee model and the post-quantum / rekeyed `SignedTransaction` envelope are out of scope.
  Their vectors are recorded in `DeferredVectors.swift` or by name; follow-up changes add their
  own test files, because a change cannot edit a predecessor's test file.
- Live-node verification stays outside the deterministic pull-request lane and uses only `GET` and
  `POST /v2/transactions/simulate`.

## Out of Scope

- `REQ-algorand-*` numbers 019 and beyond: the v42 fee model, the `SignedTransaction` authorization
  envelope (`sig` / `sgnr` / `msig` / `lsig` / `pqsig`), the v42 `al` access list and `aprv`
  reject-version fields, and the heartbeat and state-proof transaction types.
- `MaxAppTotalTxnReferences` (the combined accounts + apps + assets + boxes cap). Only the
  foreign-application count is checked client-side, because that is the array this change writes
  into; the node rejects the rest with a precise message.
- A public named type for box references. The tuple's contract was always "application ID"; only the
  encoder disagreed. Ergonomics can be revisited separately, without another wire change.
