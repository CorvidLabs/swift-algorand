---
change: adopt-specsync-module-owns-for-algorand-and-pin-trust-to-specsync-6-0-0-rc-14
artifact: context
---

# Context

CorvidLabs/spec-sync#755 landed on main and shipped as SpecSync `v6.0.0-rc.14`. It adds `[modules."<name>"] owns` so a module can take lifecycle ownership of paths beyond its spec `files:` — notably tests, `Package.swift`, and DocC catalogs that a whole-tree bootstrap signed as `@exact:test` / `@exact:delivery`.

On this repository, accepted `CHG-0001` signed every `Tests/AlgorandTests/*` entry `@exact:test` and signed `Package.swift` plus `Sources/Algorand/Algorand.docc/*` `@exact:delivery`. Exact-only inputs cannot be superseded under `algorand` without either an audited reopen of the bootstrap (which would replay its delta) or the new `owns` grant. SpecSync's own field tests name this stack explicitly.

Trust `v1.2.0-rc.4` still defaults to SpecSync `6.0.0-rc.12`, which predates `owns`. Consumers must pass `specsync-version: "6.0.0-rc.14"` (or newer) so CI installs a binary that understands the config key. Nothing under `.specsync/` is ownable; this change does not claim ownership there.

Constraints: do not reopen `CHG-0001`; do not change SDK sources or the `algorand` spec; do not merge this PR as part of the adoption work.
