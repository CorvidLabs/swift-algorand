---
spec: algorand.spec.md
---

## Requirements

- **REQ-swift-algorand-001** (stable): The package shall validate and encode existing Algorand accounts, addresses, mnemonics, amounts, hashes, signatures, and transaction wire data consistently.
- **REQ-swift-algorand-002** (stable): Transaction builders and atomic groups shall enforce required fields, preserve ordering, and return explicit failures for invalid construction.
- **REQ-swift-algorand-003** (stable): Algod and Indexer actors shall expose the existing asynchronous request and response behavior without hiding transport or decoding failures.
- **REQ-swift-algorand-004** (stable): Native verification shall build and test the package without performing credentialed TestNet sends or implicitly starting external networks.

## Constraints

- Supported platform minimums and Swift 6 package compatibility remain as declared in `Package.swift`.
- Live networks and transaction submission require independently authorized access.

## Out of Scope

- Changing public SDK behavior, platform minimums, protocol encodings, releases, or network credentials.
