---
id: CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk
state: archived
type: migration
base_commit: 0a792af561f4136451cdd4823f2c6cb8e8f15d25
---

# Adopt SpecSync 5.0.1 and Trust 1.0.0 governance for the Swift Algorand SDK

## Intent

Adopt SpecSync 5.0.1 and Trust 1.0.0 governance for the Swift Algorand SDK

## Affected Canonical Specs

- `algorand`

## Acceptance Criteria

- Strict SpecSync 5.0.1 passes at 100% source and public-export coverage with a 100/100 spec score; all four agent integrations are installed; Trust doctor passes; Swift build and the existing CI-bounded test suite pass on normal runners; macOS, Linux, DocC, localnet, and TestNet boundaries remain intact

## No-spec Rationale

Not applicable

## Migration Note

Migrated by hand to SpecSync 6 per Leif's decision (2026-09-28); the 6.0.0 tool refused to archive this legacy record (`` exact-only delivery input `.github/workflows/docs.yml` changed after acceptance and requires an audited reopen; run `specsync change reopen CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk` to re-verify the accepted change, or supersede it from a later change under a module granted the path by `owns` in `.specsync/config.toml` ``).

- Workflow v1 (SpecSync 5) record, accepted on 2026-09-06 by the closing approval already stored in `approvals.json`. Its accepted evidence went stale when later commits changed its delivery inputs.
- Moved by hand from `.specsync/changes/CHG-0001-adopt-specsync-5-0-1-and-trust-1-0-0-governance-for-the-swift-algorand-sdk/` into the layout `specsync change archive` writes: `accepted-state.json` is the unchanged accepted `state.json`, `state.json` is marked `archived`, and this file's front matter says `archived`.
- `approvals.json`, `verification.json`, `verification-attempts.json` and every other artifact are the original SpecSync 5 evidence, unchanged. `verification.json` verifies commit `35652be7fd242ffcdb9d205e1b056a6d17cf24d0`, not the tree this record was archived from.
- This migration added no verification evidence, test result, attempt history, or approval. It is a manual migration, not a fresh re-verification.
- Closing it through the tool takes `specsync change reopen`, `specsync change verify`, then `specsync change accept`, which writes a new closing approval. Per Leif's decision it was archived by hand instead, so no reopen or new approval is recorded.
