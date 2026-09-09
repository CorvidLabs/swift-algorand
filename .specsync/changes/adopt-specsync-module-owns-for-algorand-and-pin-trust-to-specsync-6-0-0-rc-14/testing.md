---
change: adopt-specsync-module-owns-for-algorand-and-pin-trust-to-specsync-6-0-0-rc-14
artifact: testing
---

# Testing

- Parse/load: SpecSync `6.0.0-rc.14` `change show` / `change status` against the updated `.specsync/config.toml` succeeds and lists the operations package.
- Config surface: `owns` contains exactly `Tests`, `Package.swift`, and `Sources/Algorand/Algorand.docc`; no `.specsync/` entry.
- Trust pin: workflow passes `specsync-version: "6.0.0-rc.14"` to `CorvidLabs/trust@v1.2.0-rc.4`.
- Regression: no `Sources/Algorand/*.swift` or `specs/algorand/**` edits in this change; SDK behavior is unchanged.
- CI honesty: Trust on this PR uses the pinned rc.14 binary. Release assets were confirmed present before the pin. Do not fall back to a main-built binary; this repo has never done that.
