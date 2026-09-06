---
change: prepare-0-4-0-release-documentation-and-migration-notes-for-the-merged-sdk-changes
artifact: tasks
---

# Tasks

- [x] Fetch merged main and identify the release candidate and prior tag.
- [x] Run baseline Trust and verify HEAD provenance.
- [x] Draft the release notes and bounded documentation scope.
- [x] Obtain user scope approval and record it with SpecSync (0xLeif: "ok go").
- [x] Check for delivery ownership requirements; address any reported by scoped verification.
- [x] Create release preparation branch and update the five declared paths.
- [x] Run strict canonical spec validation; build DocC and typecheck guide examples. Scoped verification is the next lifecycle gate.

## Lifecycle handoff

Run scoped verification, commit the candidate, and run Trust on the committed diff; record and verify candidate provenance. Prepare the PR for human inspection, then record the actual review and finalize before merge. Publication requires a separate instruction. These are lifecycle gates, not incomplete implementation tasks.
