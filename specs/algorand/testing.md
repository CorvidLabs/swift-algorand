---
spec: algorand.spec.md
---

## Test Plan

- Run the existing account, address, mnemonic, amount, hash, transaction, asset, application, group, and key-registration tests with the repository's CI environment boundary so localnet-only cases are skipped.

- Build and test on the existing macOS and Swift 6 Linux workflows.
- Keep DocC Pages publication independent.
- Do not send transactions or require live TestNet credentials in the Trust lane.
