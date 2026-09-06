---
spec: algorand.spec.md
---

## Context

The repository is a pre-1.0 cross-platform Swift SDK with macOS and Linux build/test workflows, DocC Pages publication, optional Docker localnet testing, and explicitly credentialed TestNet transaction paths.

## Related Modules

- AlgoTest and other Swift Algorand consumers depend on this package.

## Design Decisions

- Preserve the existing platform matrix and async public API.
- Keep live network and transaction-sending checks separately authorized.
- Keep standalone DocC Pages publication outside Trust-managed Atlas.
- Canonical MessagePack omit-empty is enforced at one internal choke point, not per transaction type, so a new transaction type cannot reintroduce the defect by omission.
- go-algorand at the pinned tag is the sole byte authority for transaction encoding. py-algorand-sdk deviates on `apan`, `nonpart`, and `lx` and is not authoritative.
- New test suites use Swift Testing: swift-corelibs-xctest carries an open lost-wakeup deadlock (#504) that fast synchronous XCTest classes trigger on Linux.
- Every change that materializes into specs/algorand must declare `--path specs/algorand` at creation and supersede the predecessor's spec companions, or the predecessor stays stale on the spec and finalize refuses.
- Test files are exact-only delivery inputs of the change that writes them; a later change never edits a predecessor's test file and adds its own suite instead, reading `DeferredVectors.swift` for vectors recorded ahead of time.
