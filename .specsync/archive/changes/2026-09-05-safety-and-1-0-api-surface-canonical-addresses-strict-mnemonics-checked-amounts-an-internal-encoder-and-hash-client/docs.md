---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: docs
---

# Docs

## What changed for a caller

- `Address(string:)` accepts only the canonical rendering; `Mnemonic.decode` and
  `Account(mnemonic:)` accept only the canonical spelling. Both are what go-algorand and
  py-algorand-sdk accept, so an address or phrase that worked with any other Algorand tool still
  works; one that only this SDK accepted now throws the existing `invalidAddress` /
  `invalidMnemonic`.
- `MicroAlgos` gains `adding`, `subtracting`, `multiplied(by:)`, `divided(by:)`,
  `init(checkedAlgos:)`, and `microAlgosPerAlgo`; `AssetParams` gains `baseUnits(for:)`. They
  throw `AmountError` (`overflow`, `divisionByZero`, `notRepresentable`). The operators,
  `init(algos:)`, and `toBaseUnits` still compile, deprecated with a message naming the
  replacement; the new conversions round to the nearest unit where the old ones truncated.
- `AlgorandError.invalidURL` is what a bad client base URL now reports.
- `AlgorandConfiguration(network:)`, `.localnet()`, `.testnet()`, `.mainnet()` throw; `custom`
  does not; `algodURL` and `indexerURL` are stored; `defaultLocalnetAPIToken` names the token.
- `applicationBox(_:name:)` takes `Data`; `simulateTransaction` sends MessagePack and
  `SimulateRequestTransactionGroup` holds `[Data]` with an `init(signedTransactions:)`;
  `waitForConfirmation` keeps polling through a 404 and rejects an overflowing timeout.
- `PendingTransaction.txn` and `TransactionData` are gone; `BlockResponse` has fields;
  `IndexerAsset.params` is an `AssetParamsResponse` (deprecated typealias `IndexerAsset.AssetParams`).
- `MessagePackWriter`, `MessagePackValue`, and `SHA512_256` are no longer public.
- `Account`'s public API is unchanged; its key storage is described in SECURITY.md.
- `Package.swift` is unchanged: consumers still resolve `swift-docc-plugin` (see the follow-up).

## Source-breaking changes

Maintainer-approved for 1.0: canonical-only `Address(string:)` and strict `Mnemonic.decode` (for
callers passing input the network rejects); the internalised encoder and hash; `applicationBox`'s
`Data` parameter; `SimulateRequestTransactionGroup.txns` as `[Data]`; the throwing
`AlgorandConfiguration` initializer and well-known factories; the removed `PendingTransaction.txn`
and `TransactionData`; `IndexerAsset.params`'s type. Everything the frozen test files use is
deprecated, not broken.

## Where the documentation lives

- Every public symbol carries a doc comment; the deprecated ones say what replaces them and why.
- `README.md`: the canonical-address and strict-mnemonic notes under Core Concepts, the rewritten
  Amounts section with the checked API, a "Simulating, confirming, and reading boxes" section, a
  "Changes on the road to 1.0" table, the `try` on `AlgorandConfiguration`, and the note that the
  frozen XCTest files print deprecation warnings while the library builds clean.
- `SECURITY.md` (root): the random sources per path; key storage as `Curve25519.Signing.PrivateKey`;
  what swift-crypto's `SecureBytes` (`memset_s`, BoringSSL) and CryptoKit do; what is not
  guaranteed (caller-owned copies, swap, core dumps, memory readers); canonical input; the DocC
  plugin as opt-in. It never calls clearing a boundary.
- `documentation/SECURITY.md`, `GETTING_STARTED.md` (pin, `checkedAlgos`, the 404 note, the error
  types), `QUICKSTART.md` (pin, `checkedAlgos`, `try` on the configuration factories), and
  `TESTING.md` (the Swift Testing suites and the expected deprecation warnings).
- **Not in this change:** the DocC catalog (`Sources/Algorand/Algorand.docc/GettingStarted.md`
  still pins `from: "0.1.0"`, uses the bare-string product, calls `MicroAlgos(algos:)` and the
  non-throwing configuration factories, and force-unwraps `indexerURL`) and `Package.swift`. Both
  are exact-only delivery inputs of CHG-0001 (see `context.md`). The corrected versions are kept
  as `docc-gating.patch` alongside this change's evidence, to be applied by a change that follows
  an audited reopen of CHG-0001 with `specsync change correct-owner CHG-0001 --all-missing --spec
  algorand`.

## Required follow-up in `.github/` (out of scope here)

Once the manifest gate lands, `.github/workflows/docs.yml` must export `ALGORAND_DOCC=1` in the
environment of its "Build Documentation" step (or the job), for example:

```yaml
    - name: Build Documentation
      env:
        ALGORAND_DOCC: "1"
      run: |
        swift package --allow-writing-to-directory ./docs \
          generate-documentation --target Algorand \
          --disable-indexing \
          --transform-for-static-hosting \
          --hosting-base-path swift-algorand \
          --output-path ./docs
```

Without it the plugin is not in the manifest and `generate-documentation` is not a known
subcommand. `fledge.toml` has no documentation task (and is itself an exact-only input of
CHG-0001), so no lane note is added.

## Facts worth repeating anywhere the SDK is described

- An address is accepted only in canonical form; a mnemonic only in canonical spelling.
- Checked amount operations throw `AmountError`; the trapping ones are deprecated.
- `simulate` failures other than signatures arrive as HTTP 200 with `failureMessage` set.
- A `404` while waiting for confirmation is "not yet", not an error.
- Key clearing is best effort in the cryptography library's storage and never a security boundary.
