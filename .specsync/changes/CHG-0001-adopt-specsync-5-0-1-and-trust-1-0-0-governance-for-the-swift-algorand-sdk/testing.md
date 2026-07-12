---
change: CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk
artifact: testing
---

# Testing

- Strict SpecSync at advisory threshold zero
- All four agent integrations and Trust doctor
- `swift build`
- `CI=true swift test`: 98 tests executed, 20 localnet-only tests skipped, zero failures
- Existing macOS and Swift 6 Linux hosted workflows
- No TestNet sends or live network access
