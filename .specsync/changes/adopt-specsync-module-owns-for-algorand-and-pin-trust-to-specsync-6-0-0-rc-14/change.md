---
id: adopt-specsync-module-owns-for-algorand-and-pin-trust-to-specsync-6-0-0-rc-14
state: implementing
type: operations
base_commit: 4e63b9e0833d9ce3ceb2ca8f6233f7a108d8441b
---

# Adopt SpecSync module owns for algorand and pin Trust to SpecSync 6.0.0-rc.14

## Intent

Adopt SpecSync module owns for algorand and pin Trust to SpecSync 6.0.0-rc.14

## Affected Canonical Specs

- None

## Acceptance Criteria

- .specsync/config.toml declares [modules."algorand"] owns for Tests, Package.swift, and Sources/Algorand/Algorand.docc; Trust workflow pins SpecSync 6.0.0-rc.14; SpecSync parses owns; no SDK source behavior change

## No-spec Rationale

Governance-only configuration: grant algorand module owns for Tests, Package.swift, and DocC, and pin Trust to SpecSync 6.0.0-rc.14. No SDK behavior or canonical requirements change.
