---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: context
---

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
