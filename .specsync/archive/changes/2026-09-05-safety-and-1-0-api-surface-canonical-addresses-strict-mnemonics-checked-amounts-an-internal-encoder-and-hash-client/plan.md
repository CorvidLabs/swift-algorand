---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: plan
---

# Plan

## Shape of the change

Three new source files, eleven modified Swift source files, one new test suite, no modified test
file, and the documentation set. `Package.swift` and the DocC catalog are untouched (see
`context.md`: exact-only inputs of CHG-0001).

| File | Role |
|---|---|
| `Sources/Algorand/AmountError.swift` (new) | `AmountError.overflow`, `.divisionByZero`, `.notRepresentable` |
| `Sources/Algorand/EndpointURL.swift` (new, internal) | Absolute http(s) parsing for both clients' string initializers |
| `Sources/Algorand/SimulateRequest+MessagePack.swift` (new, internal) | `encodedForSimulate()`: the `txn-groups`/`txns` body with `raw` splices and only the set flags |
| `Sources/Algorand/Address.swift` | Canonical-form check by re-encoding; the base32 decoder stops folding case |
| `Sources/Algorand/Mnemonic.swift` | 33-byte unpack and the 33rd-byte check |
| `Sources/Algorand/MicroAlgos.swift` | `microAlgosPerAlgo`, `init(checkedAlgos:)`, four checked methods; operators and `init(algos:)` deprecated |
| `Sources/Algorand/AssetTransaction.swift` | `baseUnits(for:)`; `toBaseUnits` deprecated |
| `Sources/Algorand/MessagePackWriter.swift`, `SHA512_256.swift` | `internal`; `MessagePackValue.raw` |
| `Sources/Algorand/AlgorandError.swift` | `invalidURL` |
| `Sources/Algorand/AlgorandConfiguration.swift` | Throwing init and factories, stored URLs, internal `Endpoint` literals, `defaultLocalnetAPIToken` |
| `Sources/Algorand/AlgodClient.swift` | `invalidURL`; test seam; 404-tolerant, overflow-checked `waitForConfirmation` with `isNotYetKnown`; `applicationBox(_:name: Data)` over `boxURL`; msgpack simulate; `get(url:)`; `PendingTransaction` without `txn`; `SimulateRequestTransactionGroup.txns: [Data]` plus `init(signedTransactions:)` |
| `Sources/Algorand/IndexerClient.swift` | `invalidURL`; the `URLComponents` guard; `IndexerAsset.params: AssetParamsResponse` with the deprecated typealias; a filled `BlockResponse` |
| `Sources/Algorand/Account.swift` | `SigningKeyBox` holding `Curve25519.Signing.PrivateKey` |
| `Tests/AlgorandTests/SafetyAndSurfaceTests.swift` (new) | 31 Swift Testing tests, five of them in a nested serialized `Transport` suite over a `URLProtocol` stub |
| `README.md`, `SECURITY.md`, `documentation/*.md` | Canonical input, checked amounts and deprecations, the client fixes, key storage, the road-to-1.0 table |
| (follow-up patch, not in this change) `Package.swift`, `Sources/Algorand/Algorand.docc/*.md` | `swift-docc-plugin` behind `ALGORAND_DOCC`; the pin, the product form, no deprecated or force-unwrapped sample; the error types in Topics |

## Steps, in the order they were taken

1. Read the base tree, the three archives' artifacts and lesson bundles, the reference design,
   the frozen tests' uses of the affected symbols, go-algorand's `UnmarshalChecksumAddress`,
   py-algorand-sdk's `to_private_key`, and swift-crypto's `SecureBytes` and Ed25519 backend.
2. Write the errors, amounts, address, mnemonic, account, configuration, endpoint parser, and
   manifest; internalise the encoder and hash; then the client edits and the simulate body.
3. Write `SafetyAndSurfaceTests`; hoist every throwing call out of `#expect`; serialize the
   transport tests after they raced each other's stub queue; replace a byte-equality signature
   check with cross-verification once CryptoKit's randomized Ed25519 signing was observed.
4. Verify: `fledge lanes run verify` green (XCTest 98 / 20 skipped / 0 failures; Swift Testing
   97 → 128 in 7 suites, 0 issues); a forced full recompile of `Sources/Algorand` with zero
   warnings; Linux `swift:6.0-jammy` build plus three test runs; read-only TestNet probes for
   simulate, the 404 poll, the box endpoint, and the indexer models.
5. Discover, through `supersede` refusals and `change audit`, that `Package.swift` and the DocC
   pages are exact-only inputs of CHG-0001; revert them to the base tree, keep the edits as a
   follow-up patch, and drop the manifest test and requirement.
6. Spec: add the three files to the frontmatter; generate the delta from the live spec so the
   `Public API` body is verbatim minus 11 rows plus 17; write the artifacts; answer the
   interview; `approve`, `check`, commit, `review`, `finalize` (patched build #753), archive
   commit, attest, push, draft PR stacked on #19.

## Risks weighed

- Deprecating operators in the same module produces warnings wherever they are used. The
  library uses none; the frozen XCTest files use them on purpose and their warnings are
  reported, not silenced.
- `Address(string:)` and `Mnemonic.decode` now reject input the old code accepted. Every
  rejected input is one go-algorand or py-algorand-sdk rejects, and the frozen tests never
  relied on leniency.
- The `URLProtocol` stub is Foundation-dependent; it was run on Linux in Docker before being
  kept unconditional.
- `AlgorandConfiguration`'s factories throwing is a source break for a one-line call. The
  alternative was a trap or a silent wrong URL.
- The DocC `GettingStarted.md` still shows `MicroAlgos(algos:)`, non-throwing configuration
  factories, `indexerURL!`, and `from: "0.1.0"` until the follow-up lands; README and
  `documentation/` are correct now.
