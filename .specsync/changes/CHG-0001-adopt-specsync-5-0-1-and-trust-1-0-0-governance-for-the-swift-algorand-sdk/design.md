---
change: CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk
artifact: design
---

# Design

Preserve all existing workflows. Add a separate Linux Swift 6 job named `trust`, pinned to immutable Trust 1.0.0. The Fledge lane builds and tests with the same CI live-network boundary. Use advisory coverage zero, blocking risk, progressive provenance, and disable Trust-managed Atlas because DocC Pages remains independent.
