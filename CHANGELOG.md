# Changelog

## 0.4.0 — Unreleased

swift-algorand 0.4.0 adds consensus v42 transaction encoding, post-quantum authorization envelopes, usage-based fees, and safer input and amount APIs. This pre-1.0 minor release includes source-breaking changes.

## Added

- Canonical MessagePack transaction encoding and reference-vector coverage for transaction IDs, groups, and box references.
- TransactionSigner and PQSigner, typed authorization, rekey-aware sgnr inference, and Falcon-1024 address derivation and pqsig envelopes. Supply a Falcon signing implementation through the callback; none is bundled.
- FeeStrategy, TransactionUsage, params-based transaction construction, and pooled group fee calculation and validation. Include post-quantum authorization usage when pricing a group.
- Checked MicroAlgos arithmetic and conversion, and AssetParams.baseUnits(for:), with AmountError for invalid values and overflow.

## Fixed

- Each client owns a URLSession with effective timeouts.
- Client URL handling, binary application-box queries, and MessagePack simulation requests.
- Confirmation polling continues through an initial 404 and rejects round-counter overflow.
- Key generation uses cryptographically secure randomness.

## Migration from 0.3.x

- Address and mnemonic input must be canonical; previously accepted noncanonical inputs now throw.
- Add try to AlgorandConfiguration(network:), localnet(), testnet(), and mainnet().
- Pass Data to applicationBox(_:name:). SimulateRequestTransactionGroup.txns contains encoded Data; use init(signedTransactions:) when starting from signed transactions.
- PendingTransaction.txn and TransactionData were removed. IndexerAsset.params uses AssetParamsResponse; the nested typealias is deprecated.
- MessagePackWriter, MessagePackValue, and SHA512_256 are internal implementation details.
- Replace deprecated amount operators and conversions with checked throwing APIs. Checked conversions round to the nearest base unit; older conversions truncated.
- Prefer params-based constructors for usage-aware fees. Header-field constructors retain their explicit/default fee behavior.

## Documentation and tooling

DocC documentation, synchronized module contracts, and the Trust verification workflow accompany the SDK changes. Swift 6 and existing deployment minimums are unchanged.

Full comparison: https://github.com/CorvidLabs/swift-algorand/compare/0.3.2...0.4.0 (available after tagging).
