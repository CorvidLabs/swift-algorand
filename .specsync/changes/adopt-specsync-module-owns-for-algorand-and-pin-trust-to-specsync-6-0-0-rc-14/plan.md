---
change: adopt-specsync-module-owns-for-algorand-and-pin-trust-to-specsync-6-0-0-rc-14
artifact: plan
---

# Plan

1. Confirm `v6.0.0-rc.14` exists with release assets (linux/macOS) before pinning Trust to it.
2. Add `[modules."algorand"] owns = ["Tests", "Package.swift", "Sources/Algorand/Algorand.docc"]` to `.specsync/config.toml`. Keep comments clear that this is lifecycle ownership only (not a `check` source mapping) and that `.specsync/` stays unowned.
3. Pin `.github/workflows/trust.yml` with `specsync-version: "6.0.0-rc.14"` while leaving the Trust action SHA at `v1.2.0-rc.4`.
4. Carry this work as an operations / no-spec SpecSync change so Trust path coverage for the two meaningful files is explicit rather than relying forever on bootstrap `CHG-0001`.
5. Open a PR; do not merge. Later product changes that touch tests, `Package.swift`, or DocC can `change supersede --spec algorand` against the bootstrap without reopening it.
