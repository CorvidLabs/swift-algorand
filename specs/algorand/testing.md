---
spec: algorand.spec.md
---

## Test Plan

- Run the existing account, address, mnemonic, amount, hash, transaction, asset, application, group, and key-registration tests with the repository's CI environment boundary so localnet-only cases are skipped.

- Build and test on the existing macOS and Swift 6 Linux workflows.
- Run the canonical golden-vector suite (Swift Testing), asserting byte equality of the encoded transaction and the transaction identifier against vectors derived from go-algorand v5.0.1-stable. py-algorand-sdk is not a byte oracle and must not be used as one.
- Require SpecSync to report 21/21 source files, 100% source coverage, all 344 unique exports documented, and a 100/100 quality score.
- Live-node conformance via `POST /v2/transactions/simulate` stays outside the Trust lane, is read-only, and never calls `POST /v2/transactions`.
- Keep DocC Pages publication independent.
- Do not send transactions or require live TestNet credentials in the Trust lane.
