---
change: prepare-0-4-0-release-documentation-and-migration-notes-for-the-merged-sdk-changes
artifact: context
---

# Context

The user merged PRs #17–20 and requested preparation for 0.4.0. Local main was fast-forwarded to bd193ad4dcc66d0c9f938fa97f5c41298588649c. Latest existing tag is 0.3.2; preserve the unprefixed convention for eventual 0.4.0. Fledge release dry-run finds no version files and defaults to a v-prefixed tag, so do not execute it unchanged.

Baseline verification: fledge trust verify --range 0.3.2..HEAD passed. Build and tests passed; Augur returned review, risk 35, not block. Spec coverage was 36/36 files and 384/384 exports, with a requirements re-validation warning. Progressive provenance was degraded for the historical range. A local agent:codex attestation was subsequently recorded for HEAD with testsPassed=true and verdict=review; fledge attest verify --commit HEAD passed. This does not attest every historical commit or imply human approval.

Existing untracked .agents/ belongs to the user. No SDK implementation changes are intended. The manifest's DocC opt-in gate is a separate follow-up and is excluded from this documentation-only release scope; docs build currently succeeds with the unconditional plugin. Existing SpecSync ownership may require a supported correction/supersession before editing delivery paths; never rewrite archived approval evidence.

Pending decision: user approval of the five-path release documentation scope. No scope approval has been granted or recorded. No tag or GitHub release has been created.

Implementation evidence: strict spec validation passed with zero warnings; DocC built successfully with six existing source-comment warnings (timeout parameters, internal boxURL link, and checkedAlgos parameter label). Guide examples typecheck with only unused-local warnings. Inspection established indexerURL remains optional; the guide now unwraps it with guard rather than force-unwrapping. This corrects the proposal wording without changing the documentation-only scope. No network examples were executed.
