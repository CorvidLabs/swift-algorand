# Lesson bundle — prepare-0-4-0-release-documentation-and-migration-notes-for-the-merged-sdk-changes

Material for folding this change's lessons into the affected specs' `context.md`.
Synthesise from what actually happened below; do not restate the change description.

## What this change was

- **Title**: Prepare 0.4.0 release documentation and migration notes for the merged SDK changes
- **Kind**: Documentation
- **Paths**: README.md, documentation/GETTING_STARTED.md, documentation/QUICKSTART.md, Sources/Algorand/Algorand.docc/GettingStarted.md, CHANGELOG.md
- **Acceptance**: Installation snippets pin the 0.4.x line starting at 0.4.0; DocC examples use explicit package products, throwing configuration factories, checked amounts, and the nonoptional indexer URL; CHANGELOG.md describes changes since 0.3.2, source-breaking migrations, and the externally supplied Falcon signer; scoped SpecSync and Trust verification pass before release. Prepare only, without publishing a tag or release.

## Evidence

- Verification commit: `1325979210ebe5941d9037fdd8f22da38b011447`
- Base commit: `bd193ad4dcc66d0c9f938fa97f5c41298588649c`
- Verified by: `specsync check (no spec in scope)`

## From the change's context.md

# Context

The user merged PRs #17–20 and requested preparation for 0.4.0. Local main was fast-forwarded to bd193ad4dcc66d0c9f938fa97f5c41298588649c. Latest existing tag is 0.3.2; preserve the unprefixed convention for eventual 0.4.0. Fledge release dry-run finds no version files and defaults to a v-prefixed tag, so do not execute it unchanged.

Baseline verification: fledge trust verify --range 0.3.2..HEAD passed. Build and tests passed; Augur returned review, risk 35, not block. Spec coverage was 36/36 files and 384/384 exports, with a requirements re-validation warning. Progressive provenance was degraded for the historical range. A local agent:codex attestation was subsequently recorded for HEAD with testsPassed=true and verdict=review; fledge attest verify --commit HEAD passed. This does not attest every historical commit or imply human approval.

Existing untracked .agents/ belongs to the user. No SDK implementation changes are intended. The manifest's DocC opt-in gate is a separate follow-up and is excluded from this documentation-only release scope; docs build currently succeeds with the unconditional plugin. Existing SpecSync ownership may require a supported correction/supersession before editing delivery paths; never rewrite archived approval evidence.

Pending decision: user approval of the five-path release documentation scope. No scope approval has been granted or recorded. No tag or GitHub release has been created.

Implementation evidence: strict spec validation passed with zero warnings; DocC built successfully with six existing source-comment warnings (timeout parameters, internal boxURL link, and checkedAlgos parameter label). Guide examples typecheck with only unused-local warnings. Inspection established indexerURL remains optional; the guide now unwraps it with guard rather than force-unwrapping. This corrects the proposal wording without changing the documentation-only scope. No network examples were executed.

## From the change's design.md

# Design

Update README.md, documentation/GETTING_STARTED.md, documentation/QUICKSTART.md, and Sources/Algorand/Algorand.docc/GettingStarted.md to recommend .upToNextMinor(from: "0.4.0"). Preserve references to 0.3.x when describing migration history; update present-tense release and pin explanations to 0.4.x.

In the DocC guide, use .product(name: "Algorand", package: "swift-algorand"), add try to configuration factories, use MicroAlgos(checkedAlgos:), and remove the force unwrap on config.indexerURL. Check the snippets against the current public signatures.

Add CHANGELOG.md with a 0.4.0 release candidate section containing the release copy in docs.md. Leave the publication date unset until publication. Explain the source-breaking changes explicitly and retain the pre-1.0 notice. No canonical spec behavior changes are needed.

After approval, implement on leif/prepare-0.4.0, validate scoped SpecSync and strict spec checks, build DocC, and run Trust. Surface any Augur block. Record and verify provenance only after the verification lane passes. Have the user review the resulting diff before recording human review. Prepare a PR; tagging and publishing remain a separate user action.

## Where these lessons go

This change declared no affected specs, so there is no module context to fold into.
