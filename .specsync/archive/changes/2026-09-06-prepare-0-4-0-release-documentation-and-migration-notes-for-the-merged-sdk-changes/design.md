---
change: prepare-0-4-0-release-documentation-and-migration-notes-for-the-merged-sdk-changes
artifact: design
---

# Design

Update README.md, documentation/GETTING_STARTED.md, documentation/QUICKSTART.md, and Sources/Algorand/Algorand.docc/GettingStarted.md to recommend .upToNextMinor(from: "0.4.0"). Preserve references to 0.3.x when describing migration history; update present-tense release and pin explanations to 0.4.x.

In the DocC guide, use .product(name: "Algorand", package: "swift-algorand"), add try to configuration factories, use MicroAlgos(checkedAlgos:), and remove the force unwrap on config.indexerURL. Check the snippets against the current public signatures.

Add CHANGELOG.md with a 0.4.0 release candidate section containing the release copy in docs.md. Leave the publication date unset until publication. Explain the source-breaking changes explicitly and retain the pre-1.0 notice. No canonical spec behavior changes are needed.

After approval, implement on leif/prepare-0.4.0, validate scoped SpecSync and strict spec checks, build DocC, and run Trust. Surface any Augur block. Record and verify provenance only after the verification lane passes. Have the user review the resulting diff before recording human review. Prepare a PR; tagging and publishing remain a separate user action.
