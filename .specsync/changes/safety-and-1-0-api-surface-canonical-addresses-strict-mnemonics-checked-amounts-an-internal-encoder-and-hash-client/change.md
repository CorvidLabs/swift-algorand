---
id: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
state: implementing
type: feature
base_commit: 4665470f59cbd6b382ebefca4515575c0a0aaa83
---

# Safety and 1.0 API surface: canonical addresses, strict mnemonics, checked amounts, an internal encoder and hash, client fixes, key storage, and a gated DocC plugin

## Intent

Safety and 1.0 API surface: canonical addresses, strict mnemonics, checked amounts, an internal encoder and hash, client fixes, key storage, and a gated DocC plugin

## Affected Canonical Specs

- `algorand`

## Acceptance Criteria

- Address(string:) accepts only the canonical 58-character uppercase rendering whose decoded bytes re-encode to the input (go-algorand UnmarshalChecksumAddress), rejecting lowercase and the three same-checksum trailing-bit variants of a real TestNet address with invalidAddress; Mnemonic.decode rejects all 255 non-canonical spellings of a key (33rd unpacked byte non-zero) with invalidMnemonic while the py-algorand-sdk vectors and the legacy MnemonicTests pass unchanged; MicroAlgos gains adding, subtracting, multiplied(by:), divided(by:), init(checkedAlgos:) and AssetParams gains baseUnits(for:), all throwing AmountError where the deprecated operators, init(algos:), and toBaseUnits trap, with those kept unchanged and deprecated so the 14 frozen XCTest files compile and pass; MessagePackWriter, MessagePackValue, and SHA512_256 are internal with a raw case, and every golden-vector suite passes byte-for-byte; AlgorandError.invalidURL replaces invalidAddress for bad base URLs; applicationBox takes Data and requests /v2/applications/{id}/box?name=b64%3A... through URLComponents; simulateTransaction posts application/msgpack {"txn-groups":[{"txns":[<raw signed txns>]}]} and decodes the response; waitForConfirmation keeps polling through algod's 404 in the same order and rejects an overflowing timeout; the four force unwraps are gone; PendingTransaction.txn and TransactionData are removed, BlockResponse carries the block header and transactions, IndexerAsset.params is an AssetParamsResponse with a deprecated typealias; Account stores a Curve25519.Signing.PrivateKey and SECURITY.md states per platform what is and is not guaranteed without calling zeroing a boundary; Package.swift and the DocC catalog are unchanged because they are exact-only delivery inputs of CHG-0001, with the prepared edits kept as a follow-up patch; on a live TestNet v42 node, read-only, simulate reaches overspend for an unfunded throwaway sender, waitForConfirmation on an unknown ID tolerates the 404 and throws the timeout error, and applicationBox returns a real box whose base64 name contains '+'; fledge lanes run verify is green with XCTest exactly 98 / 20 skipped / 0 failures and Swift Testing 97 -> 128 with 0 issues on macOS and three runs out of three on Linux swift:6.0-jammy; a forced full recompile of Sources/Algorand emits no warning; no predecessor test file is edited.

## No-spec Rationale

Not applicable
