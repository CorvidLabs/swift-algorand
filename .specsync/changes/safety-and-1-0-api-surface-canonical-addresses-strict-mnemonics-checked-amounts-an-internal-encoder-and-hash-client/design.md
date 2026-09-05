---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: design
---

# Design

## Canonical by comparison, not by reimplementation

`Address(string:)` decodes with the existing base32 helper (now case-strict), checks the checksum
as before, and then re-encodes the 36 bytes and requires equality with the input - go-algorand's
own rule, in go-algorand's own order. `description` is the re-encoded string, so it cannot disagree
with `bytes`. `Mnemonic.decode` unpacks every bit the 24 words carry (33 bytes) and requires the
33rd byte to be zero before the checksum, py-algorand-sdk's own check.

## One error for amounts, deprecation instead of removal

`AmountError` (`overflow`, `divisionByZero`, `notRepresentable`) is the failure type of the checked
`MicroAlgos` methods, `init(checkedAlgos:)`, and `AssetParams.baseUnits(for:)`. The four operators,
`init(algos:)`, and `toBaseUnits(_:)` keep their bodies and gain `@available(*, deprecated,
message:)` naming the replacement, because the frozen XCTest files call them. The library calls
none of them, which is what keeps the library build warning-free; the fee model's arithmetic was
already on `UInt64` with `…ReportingOverflow`. The checked conversions round to the nearest unit,
ties to even, and reject 2^64 by comparing against `0x1p64` after rounding.

## The encoder stays where it was, one level down

`MessagePackWriter`, `MessagePackValue`, and `SHA512_256` become `internal` with no other change,
plus `MessagePackValue.raw(Data)`, which the writer appends verbatim. The simulate body is built
in `SimulateRequest+MessagePack.swift` as `["txn-groups": [["txns": [raw, …]]]]` with only the set
flags, so algod's strict decoder sees exactly the tags it declares. Every existing encoding path is
untouched and the golden-vector suites are the proof.

## Clients: reach the endpoint, keep the poll order, name the error

- `EndpointURL.parse` requires a scheme in `{http, https}` and a host; both string initializers
  throw `AlgorandError.invalidURL` through it.
- `AlgodClient.boxURL` builds the box request with `URLComponents`, setting `percentEncodedQuery`
  to `name=` plus `b64:<base64>` percent-encoded to the unreserved set, so `+`, `/`, `=`, and `:`
  survive Go's query parser. `applicationBox` takes the raw name as `Data`.
- `waitForConfirmation` computes the end round with `addingReportingOverflow`, then per round:
  query pending; on `isNotYetKnown` (an `AlgorandError.apiError` with status 404) fall through;
  otherwise return on `confirmedRound`, throw on a pool error; then `waitForBlock`. The order is the
  base tree's.
- `simulateTransaction` posts `application/msgpack` with `Accept: application/json` and decodes
  `SimulateResponse` as before. `SimulateRequestTransactionGroup.txns` is `[Data]`;
  `init(signedTransactions:)` encodes each envelope.
- An internal `init(baseURL:apiToken:requestTimeout:configuration:)` is the test seam; the public
  initializers are unchanged.

## Response models: remove the echo, fill the header, unify the parameters

`PendingTransaction.txn` and the empty `TransactionData` are removed: the value was the caller's
own signed transaction and the type dropped every byte of it. `BlockResponse` gains the indexer's
block header (`round`, `timestamp`, `genesisID`, `genesisHash`, `previousBlockHash`, `seed`,
`transactionsRoot`, `transactionsRootSha256`, `txnCounter`, `proposer`) and `transactions:
[IndexerTransaction]?`, the model the indexer client already decodes. `IndexerAsset.params` is an
`AssetParamsResponse`, the same go-algorand `model.AssetParams` algod returns, with a deprecated
`IndexerAsset.AssetParams` typealias so the old name still resolves.

## Configuration without traps

`AlgorandConfiguration` resolves its well-known literals through an internal `Endpoint` enum
whose `resolve()` throws `invalidURL`, stores `algodURL` and `indexerURL`, and therefore has a
throwing `init` and throwing `localnet()`, `testnet()`, `mainnet()`; `custom` takes parsed URLs and
uses a private memberwise path. `defaultLocalnetAPIToken` replaces the 64-character literal in the
signature.

## The key in the library's storage

`SigningKeyBox` is a `private final class` holding a `let key: Curve25519.Signing.PrivateKey`,
`@unchecked Sendable` because the key is immutable and every operation on it is non-mutating and
stateless in both backends. `Account.init()` uses `PrivateKey()` so no `Data` copy of the seed
exists; `init(privateKey:)` and `init(mnemonic:)` build the key from the caller's bytes;
`mnemonic()` encodes `rawRepresentation` and deliberately does not scrub it, because that `Data`
may alias the key's storage. `sign` wraps the backend error as `encodingError`.

## Manifest and DocC (designed, carried as a follow-up)

`Package.swift` imports Foundation and appends `swift-docc-plugin` to the dependency list only when
`ProcessInfo.processInfo.environment["ALGORAND_DOCC"]` is non-nil; `GettingStarted.md` pins the
minor line and names the product through `.product(name:package:)`. Both files are exact-only
delivery inputs of CHG-0001 that no successor change can cover, so the design is kept as a patch
and the files are unchanged here (see `context.md`).

## Public surface

Seventeen new bare names, eleven removed, seven deprecated, five signature changes, listed in
`requirements.md`. Internal additions: `EndpointURL`, `Endpoint`, `resolve`, `boxURL`,
`isNotYetKnown`, the `configuration:` seam, `encodedForSimulate`, `messagePackMap`, and
`MessagePackValue.raw`.

## Out of scope, deliberately

Whitespace-tolerant mnemonic parsing, `Address.zero`, `AssetParams` field validation and exact
decimal rendering, a full `SignedTxn` JSON model or `JSONValue` passthrough, retries in the
clients, `logs`/`inner-txns` on `PendingTransaction`, and `.github/workflows/docs.yml`.
