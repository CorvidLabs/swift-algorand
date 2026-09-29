---
change: CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk
artifact: research
---

# Research

Existing hosted CI sets the standard `CI` environment, which intentionally skips localnet-only integration cases while running the deterministic suite. Running `swift test` locally without that boundary attempts localhost Algod and Indexer access. Recent main macOS and Ubuntu workflows are green. No prior SpecSync threshold exists.
