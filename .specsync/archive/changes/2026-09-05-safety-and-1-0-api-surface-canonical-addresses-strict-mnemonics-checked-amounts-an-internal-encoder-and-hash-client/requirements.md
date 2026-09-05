---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: requirements
---

# Requirements

The canonical text lives in `deltas/algorand.md` (REQ-algorand-029 through REQ-algorand-034).
This artifact records what each requirement is for and what it deliberately does not ask.

## REQ-algorand-029: canonical addresses

go-algorand's `UnmarshalChecksumAddress` decodes, verifies the checksum, and then rejects the
input unless `short.String() == address`. That last comparison is the whole requirement: the
address type accepts exactly what every other Algorand tool accepts, and `description` is the one
rendering of the bytes. Source-breaking only for a caller passing lowercase or stray-bit input.

Not asked: a `zero` address constant or byte-count constants on the public surface.

## REQ-algorand-030: strict mnemonics

py-algorand-sdk unpacks the 24 key words to 33 bytes and raises if the 33rd is non-zero. The
requirement is that check, before the checksum. The legacy `MnemonicTests` were run first to see
whether anything depended on leniency; nothing did, so no test needed reporting.

Not asked: whitespace normalisation or case handling beyond what already existed.

## REQ-algorand-031: checked amounts, deprecated traps

Every trapping amount operation gets a throwing twin and stays where it is, deprecated. The
frozen tests are the reason the old forms cannot go, and the deprecation message is what tells a
consumer where to go. `AmountError` is one type for both `MicroAlgos` and `AssetParams` so the
two conversions fail the same way.

Not asked: `AssetParams` field validation (`validated()`), exact decimal rendering, or any
change to `MicroAlgos.algos`, which is lossy but does not trap.

## REQ-algorand-032: internal encoder and hash

`MessagePackWriter`, `MessagePackValue`, and `SHA512_256` are the wire format and hash of one
chain. Internalising them is a pure access-level change plus the `raw` case that the simulate body
needs; the byte-identity of every encoding is the property that must hold, and the golden-vector
suites are how it is shown.

## REQ-algorand-033: the client fixes

Seven additive fixes with one shape: a request that could not have reached its endpoint, a
response that was decoded and dropped, or an error that named the wrong thing. Each is proven at
the transport layer with a stub and, where marked, on a live node. The poll order in
`waitForConfirmation` is unchanged on purpose.

Not asked: retries, `logs` or `inner-txns` on `PendingTransaction`, a full `SignedTxn` JSON
model, or `JSONValue` passthrough.

## REQ-algorand-034: key storage and SECURITY.md

The requirement is the *shape* (no `Data` copy of the seed, the key type's own storage) and the
*honesty* of the document (what each platform's storage does, what is not covered, never a
boundary). The public API of `Account` is unchanged.

Not asked: a guarantee about CryptoKit's storage, which is closed source; the document says so.

## Not a requirement of this change: manifest and DocC

Gating `swift-docc-plugin` behind `ALGORAND_DOCC` in `Package.swift` and fixing the DocC
`GettingStarted.md` pin and product form were in scope and are implemented, but both files are
exact-only delivery inputs of the still-accepted CHG-0001 and cannot be superseded; the tool
requires an audited reopen of CHG-0001 first. They are carried as a follow-up patch (see
`context.md` and `docs.md`) and no requirement is written for them here.

## Public surface changed

Added, 17 bare names: `invalidURL`; `AmountError`, `divisionByZero`, `notRepresentable`;
`microAlgosPerAlgo`, `subtracting`, `multiplied`, `divided`; `baseUnits`;
`defaultLocalnetAPIToken`; `timestamp`, `previousBlockHash`, `seed`, `transactionsRoot`,
`transactionsRootSha256`, `txnCounter`, `proposer`. Reused names, no new rows: `adding`,
`overflow`, `init`, `params`, `transactions`, `round`, `genesisID`, `genesisHash`, `txns`,
`AssetParams` (now also a deprecated typealias inside `IndexerAsset`).

Removed, 11 bare names: `MessagePackWriter`, `write`, `MessagePackValue`, `string`, `binary`,
`map`, `array`, `bool`, `SHA512_256` (internal); `txn`, `TransactionData` (removed). `hash` and
`uint` stay because `Address.hash(into:)` and `TealValue.uint` still export them.

Deprecated, unchanged in semantics: `MicroAlgos.init(algos:)`, `MicroAlgos.+`, `-`, `*`, `/`,
`AssetParams.toBaseUnits(_:)`, `IndexerAsset.AssetParams`.

Signature changes: `AlgodClient.applicationBox(_:name:)` takes `Data`;
`SimulateRequestTransactionGroup.txns` is `[Data]`; `AlgorandConfiguration.init(network:apiToken:)`,
`localnet(apiToken:)`, `testnet(apiToken:)`, `mainnet(apiToken:)` throw; `IndexerAsset.params` is
`AssetParamsResponse`; `PendingTransaction.txn` is gone. Everything else new is `internal`:
`EndpointURL`, `AlgorandConfiguration.Endpoint`, `AlgodClient.boxURL`, `AlgodClient.isNotYetKnown`,
the `configuration:` test seam, `SimulateRequest.encodedForSimulate()`, and `MessagePackValue.raw`.
