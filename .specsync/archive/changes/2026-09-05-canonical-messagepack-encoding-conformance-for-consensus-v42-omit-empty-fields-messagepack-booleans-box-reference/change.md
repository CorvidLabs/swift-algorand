---
id: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
state: archived
type: bug_fix
base_commit: 0d8a85f5c569ac2c9201a8f521ad178354e96f63
---

# Canonical MessagePack encoding conformance for consensus v42: omit-empty fields, MessagePack booleans, box reference indexes, and grouped transaction IDs

## Intent

Canonical MessagePack encoding conformance for consensus v42: omit-empty fields, MessagePack booleans, box reference indexes, and grouped transaction IDs

## Affected Canonical Specs

- `algorand`

## Acceptance Criteria

- A 69-vector golden conformance suite, generated from go-algorand v5.0.1-stable's msgp-generated marshaller, asserts byte equality of the encoded transaction and the computed transaction ID. All 15 vectors that fail against the current encoder pass: fee/fv/lv/gen/note/lease/xaid/amt omitted when zero or empty; nonpart and afrz encoded as msgpack bool; box references translated to foreign-app indexes with 0 for the current application; SignedTransaction.id() hashing the grouped encoding. Verified independently against a live consensus v42 TestNet node via /v2/transactions/simulate: each fixed form reaches balance application (HTTP 200) where the current form returns HTTP 400 'At least one signature didn't pass verification'. swift build and swift test remain green on macOS and Linux.

## No-spec Rationale

Not applicable
