---
change: CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk
artifact: testing
---

# Testing

- Strict SpecSync 5.0.1 at 100%: 19/19 source files, 344/344 unique exports, and 100/100 spec quality
- All four agent integrations and Trust doctor
- `REQ-algorand-001`: account, address, and mnemonic tests verify generation, recovery, validation, signing, verification, and round trips.
- `REQ-algorand-002`: amount, hash-vector, random-key use, and transaction-encoding tests verify protocol primitives.
- `REQ-algorand-003`: signing, transaction identifier, encoding, and invalid construction tests verify base transaction contracts.
- `REQ-algorand-004`: payment builder, encoding, signing, zero/nonzero amount, and close-out tests verify payment behavior.
- `REQ-algorand-005`: asset creation, management, transfer, opt-in, freeze, update, destroy, close-out, and signing tests verify asset behavior.
- `REQ-algorand-006`: application construction, encoding, foreign-reference, box, and signing tests verify application behavior.
- `REQ-algorand-007`: online, offline, nonparticipating, and signing tests verify key registration.
- `REQ-algorand-008`: atomic-group empty, limit, order, identifier, mixed-type, signing-account, and encoding tests verify grouping.
- `REQ-algorand-009`: Swift compilation verifies the complete async Algod surface; live node requests remain outside this deterministic lane.
- `REQ-algorand-010`: Swift compilation verifies the complete async Indexer surface and response models; live queries remain outside this deterministic lane.
- `REQ-algorand-011`: Swift 6 compilation plus configuration, decoding, and error tests verify platform, `Sendable`, `Codable`, and error contracts.
- `REQ-algorand-012`: the Fledge lane runs only `swift build` and `CI=true swift test`, with no LocalNet startup, credentials, transaction sends, DocC publication, or release.
- `swift build` passes.
- `CI=true swift test` executes 98 tests with 20 localnet-only tests intentionally skipped and zero failures.
- Existing macOS and Swift 6 Linux hosted workflows
- No TestNet sends or live network access
