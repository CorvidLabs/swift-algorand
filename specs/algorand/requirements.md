---
spec: algorand.spec.md
---

## Requirements

### REQ-algorand-001

`Account`, `Address`, and `Mnemonic` SHALL preserve Algorand key generation, recovery, checksum validation, signing, signature verification, and human-readable encoding behavior.

Acceptance Criteria
- Existing account, address, and mnemonic unit tests pass, including invalid input and round-trip cases.

### REQ-algorand-002

`MicroAlgos`, `SHA512_256`, secure randomness, and MessagePack encoding SHALL preserve protocol-compatible numeric, hash, random-byte, and canonical wire representations.

Acceptance Criteria
- Amount arithmetic and conversion, official hash vectors, generated randomness use, and transaction encoding tests pass.

### REQ-algorand-003

Base and signed transaction values SHALL preserve transaction identifiers, validity rounds, fees, genesis data, notes, leases, rekeying, signatures, and deterministic encoding failures.

Acceptance Criteria
- Transaction identifier, signing, encoding, and invalid-construction tests pass.

### REQ-algorand-004

Payment construction SHALL require sender, receiver, amount, and suggested parameters and SHALL preserve note, lease, rekey, close-out, and custom-validity behavior.

Acceptance Criteria
- Payment builder, zero and nonzero amount encoding, signing, and close-out tests pass.

### REQ-algorand-005

Asset creation, opt-in, freeze, configuration, destruction, transfer, close-out, and clawback transactions SHALL encode their existing Algorand asset fields and strict empty-address policy.

Acceptance Criteria
- Existing asset creation, management, transfer, opt-in, freeze, update, destroy, close-out, and signing tests pass.

### REQ-algorand-006

Application create, update, delete, opt-in, close-out, clear-state, and call transactions SHALL preserve programs, schemas, arguments, accounts, foreign references, boxes, completion mode, and extra-page fields.

Acceptance Criteria
- Existing application transaction construction, encoding, foreign-reference, box, and signing tests pass.

### REQ-algorand-007

Key-registration construction SHALL preserve online, offline, and nonparticipating vote, selection, dilution, state-proof, and participation fields.

Acceptance Criteria
- Existing online, offline, nonparticipating, and signing tests pass.

### REQ-algorand-008

Atomic groups SHALL reject empty or oversized groups, preserve transaction order, assign one deterministic group identifier, require matching signing accounts, and encode the signed sequence.

Acceptance Criteria
- Existing empty, size-limit, ordering, deterministic-ID, mixed-type, signing-account, and encoding tests pass.

### REQ-algorand-009

`AlgodClient` SHALL asynchronously expose node status, round waiting, suggested parameters, transaction submission and confirmation, account/application/box/asset reads, and simulation while surfacing transport, API, and decoding failures.

Acceptance Criteria
- Swift compilation validates the complete async public surface; live node calls remain outside the deterministic pull-request lane.

### REQ-algorand-010

`IndexerClient` SHALL asynchronously expose health and paginated account, transaction, asset, application, and block queries while preserving optional response fields and error propagation.

Acceptance Criteria
- Swift compilation validates the complete async query and response surface; live indexer calls remain outside the deterministic pull-request lane.

### REQ-algorand-011

Network configuration, errors, clients, and response models SHALL preserve the declared localnet, TestNet, MainNet, custom-endpoint, `Sendable`, `Codable`, and typed-failure contracts.

Acceptance Criteria
- Swift 6 builds on the existing platform workflows and existing configuration, decoding, and error tests pass.

### REQ-algorand-012

Native verification SHALL build the package and run its deterministic CI-bounded suite without starting LocalNet, using credentials, sending TestNet transactions, publishing DocC, or releasing artifacts.

Acceptance Criteria
- `swift build` and `CI=true swift test` pass, while the Trust lane contains no localnet startup, credential, send, documentation publication, or release step.

## Constraints

- Supported platform minimums and Swift 6 package compatibility remain as declared in `Package.swift`.
- Live networks and transaction submission require independently authorized access.

## Out of Scope

- Changing public SDK behavior, platform minimums, protocol encodings, releases, or network credentials.
