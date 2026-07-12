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
