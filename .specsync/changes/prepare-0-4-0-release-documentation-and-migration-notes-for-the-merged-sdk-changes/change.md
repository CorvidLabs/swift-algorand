---
id: prepare-0-4-0-release-documentation-and-migration-notes-for-the-merged-sdk-changes
state: implementing
type: documentation
base_commit: bd193ad4dcc66d0c9f938fa97f5c41298588649c
---

# Prepare 0.4.0 release documentation and migration notes for the merged SDK changes

## Intent

Prepare 0.4.0 release documentation and migration notes for the merged SDK changes

## Affected Canonical Specs

- None

## Acceptance Criteria

- Installation snippets pin the 0.4.x line starting at 0.4.0; DocC examples use explicit package products, throwing configuration factories, checked amounts, and the nonoptional indexer URL; CHANGELOG.md describes changes since 0.3.2, source-breaking migrations, and the externally supplied Falcon signer; scoped SpecSync and Trust verification pass before release. Prepare only, without publishing a tag or release.

## No-spec Rationale

Release documentation only; SDK behavior and canonical requirements remain unchanged.
