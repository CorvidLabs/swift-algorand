# Lesson bundle — safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client

Material for folding this change's lessons into the affected specs' `context.md`.
Synthesise from what actually happened below; do not restate the change description.

## What this change was

- **Title**: Safety and 1.0 API surface: canonical addresses, strict mnemonics, checked amounts, an internal encoder and hash, client fixes, key storage, and a gated DocC plugin
- **Kind**: Feature
- **Specs**: algorand
- **Paths**: Sources/Algorand, Tests/AlgorandTests, specs/algorand, Package.swift
- **Acceptance**: Address(string:) accepts only the canonical 58-character uppercase rendering whose decoded bytes re-encode to the input (go-algorand UnmarshalChecksumAddress), rejecting lowercase and the three same-checksum trailing-bit variants of a real TestNet address with invalidAddress; Mnemonic.decode rejects all 255 non-canonical spellings of a key (33rd unpacked byte non-zero) with invalidMnemonic while the py-algorand-sdk vectors and the legacy MnemonicTests pass unchanged; MicroAlgos gains adding, subtracting, multiplied(by:), divided(by:), init(checkedAlgos:) and AssetParams gains baseUnits(for:), all throwing AmountError where the deprecated operators, init(algos:), and toBaseUnits trap, with those kept unchanged and deprecated so the 14 frozen XCTest files compile and pass; MessagePackWriter, MessagePackValue, and SHA512_256 are internal with a raw case, and every golden-vector suite passes byte-for-byte; AlgorandError.invalidURL replaces invalidAddress for bad base URLs; applicationBox takes Data and requests /v2/applications/{id}/box?name=b64%3A... through URLComponents; simulateTransaction posts application/msgpack {"txn-groups":[{"txns":[<raw signed txns>]}]} and decodes the response; waitForConfirmation keeps polling through algod's 404 in the same order and rejects an overflowing timeout; the four force unwraps are gone; PendingTransaction.txn and TransactionData are removed, BlockResponse carries the block header and transactions, IndexerAsset.params is an AssetParamsResponse with a deprecated typealias; Account stores a Curve25519.Signing.PrivateKey and SECURITY.md states per platform what is and is not guaranteed without calling zeroing a boundary; Package.swift and the DocC catalog are unchanged because they are exact-only delivery inputs of CHG-0001, with the prepared edits kept as a follow-up patch; on a live TestNet v42 node, read-only, simulate reaches overspend for an unfunded throwaway sender, waitForConfirmation on an unknown ID tolerates the 404 and throws the timeout error, and applicationBox returns a real box whose base64 name contains '+'; fledge lanes run verify is green with XCTest exactly 98 / 20 skipped / 0 failures and Swift Testing 97 -> 128 with 0 issues on macOS and three runs out of three on Linux swift:6.0-jammy; a forced full recompile of Sources/Algorand emits no warning; no predecessor test file is edited.

## Evidence

- Verification commit: `ccdd9d4c4875f57d11a2791f9744b076703521e6`
- Base commit: `4665470f59cbd6b382ebefca4515575c0a0aaa83`
- Verified by: `specsync check --spec algorand`

## From the change's context.md

# Context

## What led here

The `0.3.x` line carried a set of defects that a 1.0 cannot ship, found while the canonical-encoding,
post-quantum, and fee-model changes were being verified against a live consensus v42 node:

- `Address(string:)` folded case and dropped the two trailing bits of the 58th character, so four
  distinct strings decoded to one address and `description` could be a string go-algorand's
  `UnmarshalChecksumAddress` rejects as non-canonical.
- `Mnemonic.decode` stopped unpacking at 32 bytes, so the 255 non-canonical spellings of every key
  (the eight spare bits of the 24th word set) decoded to the same key and passed the checksum.
  py-algorand-sdk's `to_private_key` rejects them by requiring the 33rd unpacked byte to be zero.
- `MicroAlgos`'s `+ - * /` and `init(algos:)`, and `AssetParams.toBaseUnits`, trap on caller input
  (`UInt64` overflow, a zero divisor, `UInt64(Double)` on NaN, negative, or 2^64 and above), and a
  trap cannot be caught. The fee-model change deliberately left `MicroAlgos` untouched for this one.
- `MessagePackWriter`, `MessagePackValue`, and `SHA512_256` were public although they are the wire
  format and hash of one chain, with no decoder and no general contract.
- `AlgodClient.applicationBox` appended `?name=…` through `appendingPathComponent`, which encodes
  the `?` as `%3F`; the request went to a path that does not exist. `simulateTransaction` posted a
  JSON body with base64 strings into a `[]SignedTxn` field algod cannot decode. `waitForConfirmation`
  threw on the node's 404 for a transaction it had not seen yet, the normal state right after
  submission. Both string initializers reported a bad base URL as `invalidAddress`.
- `AlgorandConfiguration` force-unwrapped three endpoint literals and `IndexerClient.searchAccounts`
  force-unwrapped a `URLComponents`; `TransactionData` and `BlockResponse` were empty structs that
  decoded successfully and discarded every field; `IndexerAsset.AssetParams` shadowed the top-level
  `AssetParams` inside `IndexerAsset`.
- `SecureKeyData` held the seed as a `Data` and `memset` it in `deinit`; `Data` is copy-on-write and
  the container handed the value out, so the wipe never reached the copies, and SECURITY.md claimed
  more than that could deliver.
- Every consumer resolved `swift-docc-plugin` (and `swift-docc-symbolkit`) for a plugin only the
  docs workflow invokes, and the DocC catalog's `GettingStarted.md` pinned `from: "0.1.0"` with a
  bare-string product that does not build.

## Constraints a session picking this up must respect

- The 14 legacy XCTest files and the seven later suites are `@exact:test` delivery inputs of the
  changes that wrote them. They are not edited and must keep compiling and passing. They use
  `MicroAlgos(algos:)`, the four operators, `.algos`, and `AssetParams.toBaseUnits` on happy paths
  (24 and 7 uses), so those symbols are deprecated with messages naming the replacements, never
  removed or changed. None asserts a lenient (lowercase) address or a non-canonical mnemonic; the
  legacy `MnemonicTests` pass unchanged under strict decoding, so nothing depended on leniency.
- The fee-model code (`FeeStrategy`, `TransactionUsage`, `AtomicTransactionGroup+Fees`) already does
  its arithmetic on `UInt64` with `…ReportingOverflow` and throws `FeeError.overflow`; it uses no
  `MicroAlgos` operator and is unchanged, so the library build stays warning-free after the
  deprecations. Only the frozen XCTest files emit deprecation warnings.
- Live checks are read-only: `GET` endpoints and `POST /v2/transactions/simulate` only, never
  `POST /v2/transactions`. algonode's free tier answers HTTP 403 `Daily free API quota exceeded` to
  bursts; the harness paces requests and retries that one answer.
- `.github/` is out of scope.
- **`Package.swift` and the DocC catalog cannot be modified by a successor change under the
  current ledger.** They are `@exact:delivery` inputs of CHG-0001 (still `accepted`, never
  archived) and, for the two DocC pages, of all three archives. `specsync change supersede` refuses
  them for module `algorand` ("is not a successor-eligible signed owner of predecessor path"), an
  exact owner is not a valid module name, and `specsync change audit` with the edited manifest in
  the tree reports: `CHG-0001-…: accepted change verification is stale for current delivery
  inputs: exact-only delivery input `Package.swift` changed after acceptance and requires an
  audited reopen; run `specsync change reopen CHG-0001-…` to re-verify the accepted change`.
  Finalize runs the same validation. Reopening CHG-0001 is a human-authorized governance act on
  a predecessor (`reopen --actor --reason`, then `correct-owner --all-missing --spec algorand`)
  that this session was not authorized to perform, and the earlier session documented that
  reopening the legacy change replays its v1 delta over the successors' materialization. The
  manifest gating and the DocC fixes were therefore carved out of this change: the files are at
  the base tree, the prepared edits are kept as a patch for a follow-up (see `docs.md`), and the
  audit is clean for everything else.
- The reference design in the scratchpad predates the frozen-tests rule, replaced `toBaseUnits`
  outright, and overclaimed in SECURITY.md; it was read for its analysis, not inherited.

## Decisions taken

- `Address(string:)` keeps go-algorand's exact rule by re-encoding the decoded bytes and comparing to
  the input, rather than reimplementing base32; the internal decoder also stops folding case.
- `Mnemonic.decode` unpacks all 33 bytes and checks the 33rd, py-algorand-sdk's check verbatim.
  Whitespace handling is unchanged (single spaces), to keep the change to what was asked.
- One new error type, `AmountError` (`overflow`, `divisionByZero`, `notRepresentable`), serves
  both `MicroAlgos` and `AssetParams`; `AlgorandError` gains only `invalidURL`.
- The checked conversions round to the nearest unit (ties to even), which is the correct semantics
  for a decimal a user typed (`0.29` with two decimals is 29, not 28); the deprecated forms keep
  truncating, so a migration can see the difference in the deprecation message.
- `PendingTransaction.txn` and `TransactionData` are removed rather than filled: the echo is the
  caller's own submission, modelling the full `SignedTxn` JSON is a 30-name surface nobody asked for,
  and the fields a caller acts on remain. `BlockResponse` is filled, because it was the entire
  result of a public method.
- `IndexerAsset.params` is typed as `AssetParamsResponse`, the same go-algorand `model.AssetParams`
  algod returns (verified live against asset 10458941), with a deprecated typealias for the old
  nested name, rather than a third asset-parameters type.
- `AlgorandConfiguration`'s well-known factories throw. Foundation has no total `http` URL
  constructor and a silent fallback URL would be worse than a trap; `custom` stays non-throwing.
- `Account` stores a `Curve25519.Signing.PrivateKey` in a `@unchecked Sendable` box (swift-crypto
  declares no `Sendable` for the key on every platform; the box is immutable). `mnemonic()` does not
  scrub `rawRepresentation`, which may alias the key's storage. SECURITY.md was rewritten from the
  swift-crypto source: `SecureBytes` clears with `memset_s`, Apple builds re-export CryptoKit.
- The transport tests use a `URLProtocol` stub through an internal `AlgodClient` initializer, in a
  nested `.serialized` suite because they share one response queue; they pass on Linux too.

## Supersession set

Exactly the 13 pre-existing files this change modifies, from the acceptance manifests against
base 4665470: `Account`, `Address`, `AlgodClient`, `AlgorandConfiguration`, `AlgorandError`,
`IndexerClient`, `MessagePackWriter`, `MicroAlgos`, `Mnemonic`, and `SHA512_256`, each held at one
digest by all three archives and CHG-0001 (four edges each, 40); `AssetTransaction.swift`, whose
newest holder is the fee-model archive alone (1); and the spec and requirements companions, held
by the fee-model archive (2). 43 edges, no test file. The three new source files and the new test
suite need no supersession. `Package.swift` and the two DocC pages are not modified (see above).

## From the change's design.md

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

## From the change's testing.md

# Testing

## The suite

One new Swift Testing suite, `Tests/AlgorandTests/SafetyAndSurfaceTests.swift` (31 tests: 26 in the
suite, 5 in its nested `Transport` suite, which is `.serialized` because those tests share one
`URLProtocol` stub queue). No XCTest file and no predecessor Swift Testing file is edited. The suite
uses only the replacements, never a deprecated symbol, and hoists every throwing call out of
`#expect` for the Swift 6.0 toolchain's macro. Fixtures: a real TestNet address whose final
character is canonical, the two py-algorand-sdk mnemonic vectors the legacy suite pins,
deterministic seeds, and hand-written algod/indexer JSON.

| Test | What it pins |
|---|---|
| `canonicalAddressRoundTrips` | canonical input accepted, `description` equals it, bytes round-trip, an arbitrary byte address re-parses |
| `lowercaseAddressesAreRejected` | lowercase and one lowercase character throw `invalidAddress` |
| `nonCanonicalTrailingBitsAreRejected` | the three same-checksum variants of the last character decode to the same 36 bytes and are rejected |
| `malformedAddressesAreRejected` | padding, non-alphabet digits, 57 and 59 characters, a corrupted checksum |
| `addressDecodesFromJSONCanonicallyOnly` | `Codable` follows the same rule |
| `crossSDKMnemonicVectorsStillDecode` | all-zero and all-42 vectors decode, re-encode, and validate |
| `nonCanonicalMnemonicsAreRejected` | 255 of 256 spellings rejected with `Non-canonical`, the canonical one decodes to the seed |
| `malformedMnemonicsAreRejected` | 24 words, an unknown word, a wrong checksum word |
| `generatedMnemonicsRoundTrip` | eight generated accounts restore and re-encode identically |
| `checkedArithmeticHappyPath` | `adding`, `subtracting`, `multiplied(by:)`, `divided(by:)` agree with the operators where those do not trap |
| `checkedArithmeticThrowsInsteadOfTrapping` | overflow on add and multiply, underflow on subtract, `divisionByZero`, the exact `UInt64.max` boundary |
| `checkedAlgosInitializer` | 1.0, 5.5, 0, -0.0, 1e13; 0.7 microAlgo rounds up; NaN, ±infinity, negatives, 1e30, 2^64 microAlgos exactly, 2e13 throw |
| `assetBaseUnits` | 10.5→1050, 100→10000, 0.01→1, 0.29→29, 1.5→1500000, 5→5; NaN, ±infinity, negatives, 1e30, 2^64, `Double(UInt64.max)`, 19 decimals throw |
| `amountErrorsDescribeThemselves` | the three descriptions |
| `rawValuesAreSplicedVerbatim` | `.raw` bytes copied after a sorted key; SHA-512/256 of the empty string starts `c672b8d1ef56ed28` |
| `invalidBaseURLsAreInvalidURL` | `"not a url"`, `ftp://`, no scheme, `https://`, empty → `invalidURL` on both clients; valid URLs accepted |
| `builtInEndpointsResolve` | all six literals parse; testnet, mainnet, localnet, and custom configurations carry the right URLs and tokens |
| `boxURLIsWellFormed` | `/v2/applications/600011882/box?name=b64%3A%2B%2F8%3D`, no `%3F` |
| `simulateBodyIsMessagePack` | the exact 25-byte body for two stand-in envelopes |
| `simulateFlagsAreOmittedOrCanonical` | four keys in canonical order, unset flags absent, `true` as `0xC3` |
| `simulateGroupFromSignedTransactions` | `init(signedTransactions:)` carries `encode()` bytes, which end the body |
| `responsesDecode` | a simulate response with `failure-message` and a pending response with the `txn` echo decode |
| `blockResponseDecodes` | header fields, `proposer`, nested `IndexerTransaction`, and a minimal `{"round":1}` |
| `indexerAssetDecodesFullParameters` | creator, url, `UInt64.max` total, manager, `default-frozen` through `AssetParamsResponse` |
| `notYetKnownMatchesOnly404` | 404 yes; 400, 500, `networkError`, `URLError` no |
| `Transport/waitForConfirmationToleratesA404` | status → 404 → wait-for-block(100) → confirmed 101, four requests in that order |
| `Transport/waitForConfirmationSurfacesOtherFailures` | a 500 and a pool error surface unchanged |
| `Transport/waitForConfirmationRejectsOverflowingTimeout` | `last-round` `UInt64.max` + 10 → `invalidTransaction` |
| `Transport/applicationBoxSendsALiveQueryURL` | the request the client actually sends |
| `Transport/simulatePostsMessagePack` | `Content-Type: application/msgpack`, `Accept: application/json`, body equals `encodedForSimulate()` |
| `accountKeyStorageIsStable` | the key survives `mnemonic()` (cross-verification, since CryptoKit's Ed25519 signing is randomized), mnemonic round trip, a copy signs for the same key, 31-byte seed rejected |

## Results

| Platform | XCTest | Swift Testing |
|---|---|---|
| macOS, `fledge lanes run verify` (`swift build` + `CI=true swift test`) | 98 executed, 20 skipped, 0 failures (unchanged from 4665470) | 128 tests in 7 suites, 0 issues (was 97 in 5) |
| Linux, `swift:6.0-jammy`, `swift build --build-tests` (exit 0) then 3 × `timeout 150 swift test --skip-build --disable-xctest` | not run (swift-corelibs-xctest #504) | 128 tests passed, exit 0, three runs out of three |

A forced full recompile of `Sources/Algorand` (`touch` then `swift build`) emits 0 warnings.
`swift build --build-tests` emits deprecation warnings only in the frozen XCTest files
(`MicroAlgosTests`, `AssetTests`, `IntegrationTests`, `ComprehensiveIntegrationTest`), for
`init(algos:)`, the operators, and `toBaseUnits`, which they use on purpose; they are reported here
and not silenced.

## Byte identity

Encoding is untouched apart from the `raw` case, which no transaction uses. The golden-vector suites
`CanonicalEncodingTests`, `CanonicalBoxReferenceTests`, `SignedTransactionEnvelopeTests`,
`PostQuantumVectorTests`, and `FeeModelTests` (97 tests) pass unchanged on macOS and Linux, byte for
byte against their go-algorand v5.0.1-stable vectors.

## Live verification (read-only)

Harness: a scratchpad executable depending on the worktree by path, against
`https://testnet-api.algonode.cloud` and `https://testnet-idx.algonode.cloud`, paced at 1.5 s with
a retry on the free tier's HTTP 403 `Daily free API quota exceeded`. `POST /v2/transactions` was
never called. Verbatim output:

```
=== (a) invalidURL for a bad base URL ===
AlgodClient(baseURL: "not a url") -> invalidURL("algod base URL must use http or https: not a url")

=== GET /v2/transactions/params ===
consensus-version: https://github.com/algorandfoundation/specs/tree/268b63433a907455d439995bf916f6b296018f4f
min-fee: 1000 fee: 0 last-round: 67022181 genesis-id: testnet-v1.0

=== (c) POST /v2/transactions/simulate with application/msgpack ===
throwaway sender (unfunded): YBIMKY32IT5IMKP76PGMZYRQBSZWFJR5THMV7RKBIUTG6QZSIRNACQA7YU
txid: OKDLHVTV234YJMRFONJJZD5VAVGE3D3MCGGDZHNODGOPAYUWGQFA fee: 1000 encoded: 245 bytes
HTTP 200 decoded: version 2 last-round 67022182 groups 1
group[0] failed-at: [0]
group[0] failure-message: transaction OKDLHVTV234YJMRFONJJZD5VAVGE3D3MCGGDZHNODGOPAYUWGQFA: overspend (account YBIMKY32IT5IMKP76PGMZYRQBSZWFJR5THMV7RKBIUTG6QZSIRNACQA7YU, data {AccountBaseData:{Status:Offline MicroAlgos:0.0A ...}}, tried to spend 1mA)
group[0] txn-results: 1
  txn-result[0] confirmed-round: nil pool-error:
PASS SIGNAL (overspend past signature verification): true

=== (d) waitForConfirmation with an unknown transaction ID, timeout 1 round ===
GET /v2/transactions/pending/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -> apiError(statusCode: 404, message: "{\"message\":\"could not find the transaction in the transaction pool or in the last 1000 confirmed rounds\"}\n")
  [wait] quota 403 on attempt 1; retrying in 3s
waitForConfirmation -> networkError("Transaction not confirmed after 1 rounds") after 10.0s
PASS SIGNAL (polled through the 404, waited the rounds, then timed out): true

=== (b) GET /v2/applications/{id}/box?name=b64:... ===
box name: 11 bytes, base64 Yl9fX10rLLbI2tM=
applicationBox(770095334, name:) -> round 67022366, name Yl9fX10rLLbI2tM=, value 56 base64 chars
PASS SIGNAL (box endpoint answers with the same name): true

=== (g) IndexerClient.asset decodes AssetParamsResponse ===
asset 10458941: creator VETIGP3I6RCUVLVYNDW5UA2OJMXB5WP6L6HJ3RWO2R37GP4AVETICXC55I name USDC unit USDC url https://centre.io decimals 6 total 18446744073709551615 manager 6FLEYABEB3G7ZKHL4NBCXHMMXVTEITBXI4AU3CMVXKJVEBKRRKOEY5UQEI

=== (f) IndexerClient.block decodes BlockResponse ===
block 67022363: timestamp 1788649203 genesis-id testnet-v1.0 proposer RDHEK4QHSIURYYAGVPJAUDO4XFYXHMVBNED2RAS6XBDYOG6CYKXJMMWZCQ txn-counter 771191946 transactions 5
  first transaction: 5JUS7D5IIWJVDYERWMVGHHWAX4R3KZY4HSQU54TV4O2RNS6YVLOQ appl fee 3000 confirmed-round 67022363
```

What each proves. (c): the node decoded the msgpack body and the spliced envelope, matched the
group, verified the Ed25519 signature, and reached the fee deduction of a zero-balance sender, the
same `overspend` signal the fee-model change used; the base tree's JSON body could not be decoded
into `[]SignedTxn` at all. (d): the base tree threw `apiError(404)` on the first poll; the client
now tolerates it, waits for the round (`wait-for-block-after`), and reports the timeout; the 3 s
retry in the middle is the harness re-running the whole call after a quota 403 on the block wait.
(b): the box name `b__]+,\xb6\xc8\xda\xd3` base64-encodes with a `+`, which Go's query parser would
have read as a space; the box came back under the same name. Raw `curl` comparison against the same
node: the base tree's URL `/v2/applications/12174945/box%3Fname=b64:%2B%2F8%3D` answers the router's
`{"message":"Not Found"}` (HTTP 404); the SDK's `/v2/applications/12174945/box?name=b64%3A%2B%2F8%3D`
answers algod's `{"message":"box not found"}` (HTTP 404) - the endpoint reached and the name parsed.
(g), (f): the indexer's asset parameters decode through `AssetParamsResponse` with every field the
old nested type dropped, and a real block with five transactions decodes through `BlockResponse`
and `IndexerTransaction`.

## Requirement evidence

All tests are in `Tests/AlgorandTests/SafetyAndSurfaceTests.swift`.

| Requirement | Evidence |
|---|---|
| REQ-algorand-029 | `canonicalAddressRoundTrips`, `lowercaseAddressesAreRejected`, `nonCanonicalTrailingBitsAreRejected`, `malformedAddressesAreRejected`, `addressDecodesFromJSONCanonicallyOnly`; legacy `AddressTests` unchanged. |
| REQ-algorand-030 | `crossSDKMnemonicVectorsStillDecode`, `nonCanonicalMnemonicsAreRejected`, `malformedMnemonicsAreRejected`, `generatedMnemonicsRoundTrip`; legacy `MnemonicTests` (6) unchanged. |
| REQ-algorand-031 | `checkedArithmeticHappyPath`, `checkedArithmeticThrowsInsteadOfTrapping`, `checkedAlgosInitializer`, `assetBaseUnits`, `amountErrorsDescribeThemselves`; legacy `MicroAlgosTests` and `AssetTests` unchanged through the deprecated symbols; `Sources/Algorand` recompiles with 0 warnings; `git diff 4665470 -- Sources/Algorand/FeeStrategy.swift Sources/Algorand/TransactionUsage.swift Sources/Algorand/AtomicTransactionGroup+Fees.swift` is empty. |
| REQ-algorand-032 | `rawValuesAreSplicedVerbatim`; `specsync check --strict` 384/384 with the 11 rows gone; the five golden-vector suites unchanged on macOS and Linux. |
| REQ-algorand-033 | `invalidBaseURLsAreInvalidURL`, `builtInEndpointsResolve`, `boxURLIsWellFormed`, `simulateBodyIsMessagePack`, `simulateFlagsAreOmittedOrCanonical`, `simulateGroupFromSignedTransactions`, `responsesDecode`, `blockResponseDecodes`, `indexerAssetDecodesFullParameters`, `notYetKnownMatchesOnly404`, and the five `Transport` tests; live probes (a), (b), (c), (d), (f), (g); `grep -rn '!' Sources/Algorand` finds no force unwrap. |
| REQ-algorand-034 | `accountKeyStorageIsStable`; `AccountTests`, `CanonicalEncodingTests`, `SignedTransactionEnvelopeTests` unchanged; `SECURITY.md` rewritten from swift-crypto 3.15.1's `SecureBytes.swift` (`memset_s` in `deinit`) and `CryptoKitErrors.swift` (`@_exported import CryptoKit`). |

## Where these lessons go

- `specs/algorand/context.md`
