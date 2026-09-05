---
change: canonical-messagepack-encoding-conformance-for-consensus-v42-omit-empty-fields-messagepack-booleans-box-reference
artifact: research
---

# Research

Everything below was established empirically, against a live consensus v42 node and against
go-algorand's own source at the pinned tag. Nothing here is inferred from documentation.

## 1. The network this SDK must satisfy

`GET https://testnet-api.algonode.cloud/v2/status` → `HTTP 200`

```json
{"last-round":66992586,
 "last-version":"https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f",
 "next-version":"https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f",
 "next-version-round":66992587,"next-version-supported":true}
```

`GET /versions` → `HTTP 200`

```json
{"versions":["v2"],"genesis_id":"testnet-v1.0",
 "build":{"major":5,"minor":0,"build_number":1,"commit_hash":"e763fb0d+","branch":"AVAIL","channel":"AVAIL"}}
```

`last-version == next-version == 268b63433a907455d439995bf916f6b296018f4f`, and `next-version-round`
is one past `last-round` with `next-version-supported: true`. Consensus **v42 is the running
protocol**, not a pending upgrade. The node binary is **go-algorand v5.0.1-stable**.

`GET /v2/transactions/params` → `HTTP 200` reports `"fee":0` and `"min-fee":1000`. Those are
different quantities: `fee` is the dynamic congestion fee (currently zero) and `min-fee` is the
base. A client that copies `params.fee` verbatim builds a zero-fee transaction.

The transaction type set is unchanged at eight (`pay`, `keyreg`, `acfg`, `axfer`, `afrz`, `appl`,
`stpf`, `hb`). Nothing in 4.x or 5.0 adds a ninth. This was confirmed from the live binary: a
deliberately invalid signature made the node print its own Go struct verbatim in the error body,
showing `Txn:{... Type:pay Header:{...} KeyregTxnFields:{... Nonparticipation:false}
PaymentTxnFields:{...} AssetConfigTxnFields:{...} AssetTransferTxnFields:{...}
AssetFreezeTxnFields:{...} ApplicationCallTxnFields:{... Access:[] ... RejectVersion:0}
StateProofTxnFields:{...} HeartbeatTxnFields:<nil>}`.

All verification traffic was read-only: `GET`s plus `POST /v2/transactions/simulate`.
`POST /v2/transactions` was never called. No funds moved and nothing landed on chain.

## 2. The failure, reproduced

Method: one payment, sender a throwaway unfunded account, every field held constant except that a
single zero or empty field is added explicitly. Reaching `overspend` is the marker for "signature
verification passed and execution got as far as balance application".

```
baseline (no zero fields present)  -> HTTP 200  failure-message: "transaction XBWF...: overspend (account QRW7...)"
fee: 0 explicit                    -> HTTP 400  {"message":"At least one signature didn't pass verification"}
note: b'' explicit                 -> HTTP 400  {"message":"At least one signature didn't pass verification"}
lx: 32 zero bytes explicit         -> HTTP 400  {"message":"At least one signature didn't pass verification"}
gen: '' explicit                   -> HTTP 400  {"message":"At least one signature didn't pass verification"}
amt: 0 explicit                    -> HTTP 400  {"message":"At least one signature didn't pass verification"}
grp: 32 zero bytes explicit        -> HTTP 400  {"message":"At least one signature didn't pass verification"}
rekey: zero address explicit       -> HTTP 400  {"message":"At least one signature didn't pass verification"}
close: zero address explicit       -> HTTP 400  {"message":"At least one signature didn't pass verification"}
```

Two-member group, `fee` present only on member 0:

- **correct**, `fee` key omitted on txn1. Canonical txn1 bytes
  `88a26676ce03fe39fea367656eac746573746e65742d76312e30a26768c420...a474797065a3706179` →
  `HTTP 200`, `failure-message: transaction CL7XX2YE...: overspend`, `failed-at: [0]`,
  `group-fees-paid: 2000`. Signature verification passed.
- **deviant**, `fee: 0` present. Canonical txn1 bytes begin `89a366656500a26676ce03fe39fe...`
  (a 9-entry map opening with `a3666565 00` = `"fee": 0`) → `HTTP 400`
  `{"message":"At least one signature didn't pass verification"}`.

## 3. The decisive control: this is a signing-preimage defect, not a wire-format defect

Signing bytes and transmitted bytes were deliberately decoupled.

```
A: sign CANONICAL bytes (nonpart as bool), TRANSMIT DEVIANT bytes (nonpart as uint 1)
   -> HTTP 200  "transaction NAT6WTJL...: overspend"                    SIGNATURE PASSED
B: sign DEVIANT bytes (uint), TRANSMIT DEVIANT bytes (uint)
   -> HTTP 400  {"message":"At least one signature didn't pass verification"}
C: sign CANONICAL bytes (fee omitted), TRANSMIT DEVIANT bytes (fee: 0)
   -> HTTP 200  "txgroup with 0.0A fees is less than 1mA (usage=1.000000 * base=1mA)"
                                                                        SIGNATURE PASSED
```

**Proven mechanism.** The node decodes leniently, then **re-encodes the `Transaction` canonically**
with msgp `omitempty` and verifies Ed25519 over `"TX" || canonical_bytes`. The deviant wire form is
*tolerated on the wire*. What kills the transaction is that the client computed its signature over
the deviant bytes.

Two consequences follow, and both shape the design:

1. Every omit-empty violation anywhere in the encoder is a **signing** bug, and is unconditionally
   fatal, because this SDK signs exactly the bytes it emits (`SignedTransaction.sign` calls
   `transaction.encode(groupID:)` and hashes the result).
2. The fix is not "emit something the node can parse" — the node can already parse it. The fix is
   "make the signing preimage canonical". Centralising the omit-empty rules therefore repairs the
   whole class in one place.

**Refuted hypothesis.** The earlier diagnosis that `nonpart` as a msgpack uint is a *decode type
error* which the node rejects outright is **wrong**. Control A above transmits `nonpart: 1` (uint)
and it verifies fine — go-algorand's `codec` decoder silently coerces uint 1 to bool `true`. The
rejection is a signature-verification failure with the same HTTP 400, arrived at by a different
route. This distinction matters: the fix is canonicalisation of the preimage, not a decoder
work-around.

Note for whoever reads the golden-vector file: the `keyreg_nonparticipating` vector's own
`description` string still carries the refuted wording ("is a decode type error and the node
rejects the transaction outright"). The vector's *bytes* are correct; its prose is stale and should
be corrected when the suite lands.

## 4. Unknown field names ARE a hard decode failure

```
UNKNOWN field 'lease' (misspelling of 'lx') -> HTTP 400
  {"message":"failed to decode object: json decode error [pos 1]: only encoded map or array can be decoded into a struct"}
UNKNOWN field 'zzz'                          -> HTTP 400  (same message)
```

This is the generic strict-decode error, not a JSON-specific one, despite the wording. It is the
one class of encoder mistake the node *does* reject at decode. It also makes the decoder a usable
oracle for field-tag discovery.

## 5. Box reference `i` is an index, never an application ID

App `600011882` on TestNet, approval program `BzEZgQASQw==`. Run with
`allow-empty-signatures: true` so signatures cannot confound the result.

```
i omitted (== 0, current app), apfa absent          -> HTTP 200, NO failure-message              (accepted)
i = 600011882 (raw app id, what this SDK emits)     -> HTTP 200, "tx.Boxes[0].Index is 600011882. Exceeds len(tx.ForeignApps)"
apfa=[600011882], i = 1 (1-based foreign index)     -> HTTP 200, NO failure-message              (accepted)
apfa=[600011882], i = 600011882 (raw id)            -> HTTP 200, "tx.Boxes[0].Index is 600011882. Exceeds len(tx.ForeignApps)"
apfa len 1, i = 2 (one past the end)                -> HTTP 200, "tx.Boxes[0].Index is 2. Exceeds len(tx.ForeignApps)"
i = 0 written explicitly                            -> HTTP 200, NO failure-message              (accepted)
```

This is a `wellFormed` rejection surfaced as an HTTP 200 simulate result carrying a
`failure-message`, **not** an HTTP 400. A client that only checks the status code will not notice.

go-algorand, `data/transactions/application.go` @ v5.0.1-stable:

```go
// BoxRef names a box by the slot. In the Boxes field, `i` is an index into
// ForeignApps. As an entry in Access, `i` is a index into Access itself.
type BoxRef struct {
    _struct struct{} `codec:",omitempty,omitemptyarray"`
    Index   uint64   `codec:"i"`
    Name    []byte   `codec:"n,allocbound=bounds.MaxBytesKeyValueLen"`
}
```

```go
// Resolve looks up the referenced app ... 0 is returned if the App index is 0, meaning "current app".
switch {
case br.Index == 0:
    return 0, string(br.Name), nil
case br.Index <= uint64(len(access)): // 1-based
```

and the wellFormed check itself (same file, line 549 ff.):

```go
for i, br := range ac.Boxes {
    // recall 0 is the current app so indexes are shifted, thus test is for greater than, not gte.
    if br.Index > uint64(len(ac.ForeignApps)) {
        return fmt.Errorf("tx.Boxes[%d].Index is %d. Exceeds len(tx.ForeignApps)", i, br.Index)
    }
```

## 6. The authority for omit-empty is go-algorand, at the pinned tag

Every Algorand transaction struct is tagged `_struct struct{} codec:",omitempty,omitemptyarray"`,
which the msgp generator turns into a per-field zero guard in `data/transactions/msgp_gen.go`.
Struct tags, read directly from go-algorand v5.0.1-stable:

| File | Line | Field | Wire key | Go type | Omitted when |
|---|---|---|---|---|---|
| `data/transactions/transaction.go` | 55 | `_struct` | — | — | `codec:",omitempty,omitemptyarray"` |
| `data/transactions/transaction.go` | 57 | `Sender` | `snd` | `basics.Address` | **never** (`,required`) |
| `data/transactions/transaction.go` | 58 | `Fee` | `fee` | `basics.MicroAlgos` | `Fee.MsgIsZero()` |
| `data/transactions/transaction.go` | 59 | `FirstValid` | `fv` | `basics.Round` | `FirstValid.MsgIsZero()` |
| `data/transactions/transaction.go` | 60 | `LastValid` | `lv` | `basics.Round` | `LastValid.MsgIsZero()` |
| `data/transactions/transaction.go` | 61 | `Note` | `note` | `[]byte` | `len(Note) == 0` |
| `data/transactions/transaction.go` | 62 | `GenesisID` | `gen` | `string` | `GenesisID == ""` |
| `data/transactions/transaction.go` | 63 | `GenesisHash` | `gh` | `crypto.Digest` | all 32 bytes zero |
| `data/transactions/transaction.go` | 68 | `Group` | `grp` | `crypto.Digest` | all 32 bytes zero |
| `data/transactions/transaction.go` | 75 | `Lease` | `lx` | `[32]byte` | `Lease == [32]byte{}` |
| `data/transactions/transaction.go` | 81 | `RekeyTo` | `rekey` | `basics.Address` | zero address |
| `data/transactions/transaction.go` | 89 | `Type` | `type` | `protocol.TxType` | **never** (`,required`) |
| `data/transactions/keyreg.go` | 33-38 | `VotePK`…`VoteKeyDilution` | `votekey` `selkey` `sprfkey` `votefst` `votelst` `votekd` | fixed arrays / `uint64` | all-zero / `== 0` |
| `data/transactions/keyreg.go` | 39 | `Nonparticipation` | `nonpart` | **`bool`** | `Nonparticipation == false` |
| `data/transactions/asset.go` | 34 | `ConfigAsset` | `caid` | `basics.AssetIndex` | `== 0` |
| `data/transactions/asset.go` | 38 | `AssetParams` | `apar` | nested struct | recursively empty |
| `data/transactions/asset.go` | 45 | `XferAsset` | `xaid` | `basics.AssetIndex` | `== 0` |
| `data/transactions/asset.go` | 50 | `AssetAmount` | `aamt` | `uint64` | `== 0` |
| `data/transactions/asset.go` | 56-65 | `AssetSender` `AssetReceiver` `AssetCloseTo` | `asnd` `arcv` `aclose` | `basics.Address` | zero address |
| `data/transactions/asset.go` | 74 | `FreezeAccount` | `fadd` | `basics.Address` | zero address |
| `data/transactions/asset.go` | 77 | `FreezeAsset` | `faid` | `basics.AssetIndex` | `== 0` |
| `data/transactions/asset.go` | 80 | `AssetFrozen` | `afrz` | **`bool`** | `AssetFrozen == false` |
| `data/transactions/application.go` | 103 | `ApplicationID` | `apid` | `basics.AppIndex` | `== 0` |
| `data/transactions/application.go` | 109 | `OnCompletion` | `apan` | `OnCompletion` | `OnCompletion == 0` |
| `data/transactions/application.go` | 113-144 | `ApplicationArgs` `Accounts` `ForeignAssets` `ForeignApps` `Access` `Boxes` | `apaa` `apat` `apas` `apfa` `al` `apbx` | slices | `len == 0` (`omitemptyarray`) |
| `data/transactions/application.go` | 150-156 | `LocalStateSchema` `GlobalStateSchema` | `apls` `apgs` | nested struct | recursively empty |
| `data/transactions/application.go` | 163-170 | `ApprovalProgram` `ClearStateProgram` | `apap` `apsu` | `[]byte` | `len == 0` |
| `data/transactions/application.go` | 175 | `ExtraProgramPages` | `apep` | `uint32` | `== 0` |
| `data/transactions/application.go` | 179 | `RejectVersion` | `aprv` | `uint64` | `== 0` |
| `data/transactions/application.go` | 341-343 | `BoxRef.Index` / `BoxRef.Name` | `i` / `n` | `uint64` / `[]byte` | `Index == 0` / `len(Name) == 0` |
| `data/transactions/signedtxn.go` | 36-42 | `Sig` `Msig` `Lsig` `PQsig` `AuthAddr` | `sig` `msig` `lsig` `pqsig` `sgnr` | — | zero / empty |
| `data/transactions/signedtxn.go` | 41 | `Txn` | `txn` | `Transaction` | **never** (`,required`) |

The corresponding generated guards live in `data/transactions/msgp_gen.go` at the same tag. The
struct tags in the table above were read directly from the vendored go-algorand sources in this
session; the three generated guards below were transcribed verbatim by the agent that generated the
vectors, and are recorded here in the form the msgp generator emits:

```go
if (*z).OnCompletion == 0                { ...omit apan... }
if (*z).Nonparticipation == false        { ...omit nonpart... }   // written via msgp.AppendBool / read via msgp.ReadBoolBytes
if (*z).Header.Lease == ([32]byte{})     { ...omit lx... }
```

Two `,required` fields, and only two, are written unconditionally: `Header.Sender` (`snd`) and
`Transaction.Type` (`type`). `SignedTxn.Txn` (`txn`) is the third `,required` field, in the
envelope rather than the transaction.

## 7. py-algorand-sdk is NOT a byte oracle

py-algorand-sdk 2.12.0 (MIT) was used as a *secondary* cross-check while generating the vectors. It
disagrees with go-algorand in exactly three places, all of which it gets wrong:

| Deviation | py-algorand-sdk behaviour | go-algorand behaviour | Where it shows |
|---|---|---|---|
| `apan` | `ApplicationCallTxn.dictify` writes `d['apan']` unconditionally | omitted when `OnCompletion == 0` (NoOp) | every NoOp app call — `pySdkEncodedHex` for `appl_box_self_app_id` opens `8a a46170616e 00 …` where go-algorand opens `89 a4617062 78 …` |
| `nonpart` | written whenever it is not `None`, so `KeyregOfflineTxn` emits `nonpart: false` | a `false` bool is omitted | offline keyreg |
| `lx` | `if self.lease:` is truthy for 32 zero bytes, so an all-zero lease is emitted | `Lease == [32]byte{}` is omitted | `pay_zero_lease` |

If a future session "fixes" the Swift encoder to match py-algorand-sdk, it will reintroduce the bug.
**go-algorand v5.0.1-stable's msgp-generated marshaller is the sole authority.**

## 8. Caveat on the vector generator's own simplification

`gen_vectors.py`'s `_is_empty` treats *any* all-zero byte string as empty:

```python
if isinstance(value, (bytes, bytearray)):
    return len(value) == 0 or all(b == 0 for b in value)
```

That is correct for Go **fixed-width** arrays (`[32]byte` — `lx`, `gh`, `grp`, `am`, addresses) but
**wrong** for Go **variable-length** slices (`[]byte` — `note`, `apap`, `apsu`, box `n`), where only
`len == 0` omits. No current vector exercises an all-zero non-empty slice, so the vector bytes are
unaffected; but the Swift implementation must **not** copy this shortcut. The design keeps the two
cases as separate setters for exactly this reason.

## 9. Licensing

The Algorand Foundation's `lsig_address_kat.json` is AGPL-3.0 (`algorandfoundation/falcon-signatures`)
and py-algorand-sdk's vendored `tests/unit_tests/pq_test_data/pq*.json` originate in
`algorandfoundation/algokit-polytest`, which publishes no licence at all. **Neither was copied.**
Every vector in this change is regenerated from first principles. This repository is MIT and must
stay that way.

## 10. Out of scope but recorded, so it is not re-derived

The v42 fee model was derived exactly from the same live node and is **deliberately not implemented
here** — it is a separate change (see `pay_min_fee_from_params`):

```
required_group_fee_uA = ceil( group_usage_micro * min_fee / 1_000_000 )

group_usage_micro = SUM over the group of:
      1_000_000                                        # flat, all 8 transaction types
    + 100 * max(0, len(note)                - 1024)    # free 1024,  hard max 4096
    + 100 * max(0, sum(len(a) for a in apaa) - 2048)   # free 2048,  hard max 16384
    + 100 * max(0, len(apap) + len(apsu)    - 8192)    # free 8192 (4 pages), hard max 2048*(1+apep), apep <= 7
    + 100 * max(0, len(lsig.l)              - 1000)    # free 1000 per LogicSig

check: sum(txn.fee for txn in group) >= required_group_fee_uA        # POOLED, group-level, ceiling rounding
```

Contributing nothing to usage: `apep`, `sig`, `msig`, `pqsig`, `sgnr`, boxes, `apfa`/`apas`/`apat`,
schemas. LogicSig *args* are not surcharged; they are hard-capped at a 1000-byte pool.

The v42 post-quantum envelope was likewise recovered and is **deliberately not implemented here**
(see `signed_ed25519_rekeyed_sgnr`): `pqsig: {sch: <2 bytes>, slt: <uint>, pk: <bytes>, sig: <bytes>}`,
present both at `SignedTxn` top level and nested inside `Lsig`, which also gained `LMsig`. Every
2-byte `sch` value tried returns `pq signature validation failed: pq signature scheme not supported`,
so the envelope shape is confirmed and only the scheme discriminant is unknown.

## Linux: the conformance suite deadlocks under XCTest (not an encoder defect)

Running the full suite on `swift:6.0-jammy` hung indefinitely; on macOS it completes in 0.4s.
Isolated on Linux by an lldb backtrace and a bisection:

- The hung process had only two threads: the main thread inside
  `XCTestCase.invokeTest -> awaitUsingExpectation -> XCTWaiter.wait -> RunLoop.run ->
  __CFRunLoopServiceFileDescriptors`, and libdispatch's manager thread. No frame of this
  package's code was on any stack, and no cooperative-pool worker was alive.
- Every test that hung passes when run alone (`testAfrzFreeze`: 0.002s, exit 0).
- The hang point moved between runs of the same binary: `finished=11, 31, 11, 27` over four
  runs on 6.0 (4/4 hung); `finished=2, 6, 58, 58, 58` on 6.1 (2/5 hung).
- `awaitUsingExpectation` and `XCTWaiter.wait` are byte-identical between
  `swift-6.0-RELEASE` and `swift-6.1-RELEASE`.

Mechanism: swift-corelibs-xctest runs every test body in a `Task` that fulfils an
`XCTestExpectation`, while the main thread waits in a run loop woken by `CFRunLoopStop`. When
the body completes before the main thread enters the loop, the wake is lost and the wait never
returns (the source's own comment at XCTWaiter.swift:424 names this window). Probability rises
with how fast the test body is; these are microsecond pure encodes, 58 in one class.

Upstream: swiftlang/swift-corelibs-xctest#504, "deadlock in XCTest (Swift 5.10 & Swift 6.0.x)",
OPEN since 2024-11-12 — reproduced there with thirteen *empty* `throws` tests.

Consequences recorded here so they are not re-learned:
- The pre-existing 98-test XCTest suite carries the same exposure and has passed CI by luck.
- A toolchain bump is not a mitigation (6.1 still hangs).
- The two new conformance suites run on Swift Testing, which has no `XCTWaiter`/run-loop in
  its path and ships in the 6.0 toolchain with no manifest change. Migrating the remaining
  XCTest suite is a separate change.
