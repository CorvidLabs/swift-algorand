---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: testing
---

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
