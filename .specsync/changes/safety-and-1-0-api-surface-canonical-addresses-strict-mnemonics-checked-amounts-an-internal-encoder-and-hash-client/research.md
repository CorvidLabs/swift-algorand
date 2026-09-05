---
change: safety-and-1-0-api-surface-canonical-addresses-strict-mnemonics-checked-amounts-an-internal-encoder-and-hash-client
artifact: research
---

# Research

## Canonical addresses in go-algorand

`data/basics/address.go` `UnmarshalChecksumAddress`: decode with
`base32.StdEncoding.WithPadding(base32.NoPadding)` (uppercase alphabet, so lowercase fails to
decode), require at least 32 bytes, compare the trailing four bytes with `SHA512_256(short)[28:]`,
and finally `if short.String() != address { return "non-canonical" }`. The 58th character carries two
bits past the 288 the 36 bytes use; three of its four values share the bytes and the checksum and
are rejected only by that last comparison. The SDK implements the same sequence and the same
comparison rather than a bespoke bit check.

## Canonical mnemonics in py-algorand-sdk

`mnemonic.py` `_to_key` / `to_private_key`: split, map to 11-bit indices, `_to_bytes` the first 24
words, and `if not (len(key_bytes) == 33 and key_bytes[-1] == 0): raise WrongMnemonicLengthError`
before checking the checksum. 24 words × 11 bits = 264 bits = 33 bytes; byte 32 is the spare byte.
The base tree's `fromElevenBit(_:byteCount: 32)` stopped emitting at 32 bytes, discarding the check.
The two legacy vectors (all-zero → `abandon … invest`, all-42 → `… ability tired`) have a canonical
24th word (`abandon` = 0, `ability` = 1, both with the high eight bits clear), which is why the
legacy `MnemonicTests` pass unchanged.

## Trapping conversions in Swift

`UInt64.init(_: Double)` traps for NaN, infinity, negative values, and values ≥ 2^64;
`UInt64.max` converted to `Double` rounds up to exactly 2^64, so a bound written as
`<= Double(UInt64.max)` admits a value that traps. The checked conversions compare against
`0x1p64` after rounding. `+`, `-`, `*` on `UInt64` trap on overflow and `/` on a zero divisor; the
`…ReportingOverflow` family reports instead, which is what the fee model already used.

## algod's box and simulate endpoints

`daemon/algod/api/server/v2/handlers.go`: `GetApplicationBoxByName` reads the `name` query through
echo's `QueryParam`, which calls Go's `net/url.ParseQuery`; that decoder turns a literal `+` into a
space, so a base64 value must be percent-encoded. The parameter form is `b64:<base64>`. A missing
box answers HTTP 404 `{"message":"box not found"}`; a path that does not exist answers the router's
`{"message":"Not Found"}`, which is what the base tree's `%3F` URL received.

`SimulateTransaction` decodes the body according to `Content-Type`: `application/msgpack` into
`PreEncodedSimulateRequest{TxnGroups: []PreEncodedSimulateRequestTransactionGroup{Txns:
[]transactions.SignedTxn}}`, so each `txns` element must be a `SignedTxn` map spliced verbatim; a
JSON body with base64 strings in that position fails to decode. The response is JSON by default.
Well-formedness and fee failures are reported with HTTP 200 and `failure-message`; a bad signature
is HTTP 400. An unfunded sender fails at `overspend` after signature verification, the signal the
fee-model change established.

`PendingTransactionInformation` answers 404 for a transaction neither in the pool nor in the last
1000 confirmed rounds; js-algorand-sdk's `waitForConfirmation` ignores that error and keeps
polling ("Ignore errors from PendingTransactionInformation, since it may return 404").

## swift-crypto 3.15.1 key storage

`Sources/Crypto/Util/SecureBytes.swift`: `Backing.deinit` clears the buffer with `memset_s`.
`Sources/Crypto/Keys/EC/BoringSSL/Ed25519_boring.swift`: the private key is a `SecureBytes` of 64
bytes (seed and public key) built by BoringSSL's `ED25519_keypair_from_seed`. On Apple platforms
`Sources/Crypto/CryptoKitErrors.swift` and the other shims `@_exported import CryptoKit`, so the
key type is CryptoKit's. swift-crypto declares no `Sendable` conformance on
`Curve25519.Signing.PrivateKey`, hence the `@unchecked Sendable` box. Observed on macOS: CryptoKit's
Ed25519 `signature(for:)` is randomized (two signatures of one message differ, both verify), so the
key-storage test cross-verifies rather than comparing bytes. Foundation's `URL(string:)` in Swift 6
parses `"not a url"` successfully as a relative URL, so the endpoint parser requires a scheme and a
host.

## Foundation and Swift Testing

`URLSessionConfiguration.protocolClasses` with a `URLProtocol` subclass works in
swift-corelibs-foundation as well as on Darwin; the transport tests ran three times on
`swift:6.0-jammy`. Swift Testing runs a suite's tests in parallel by default; tests sharing a
process-wide stub must sit in a `.serialized` suite.

## SpecSync exact-only delivery inputs

An acceptance manifest assigns `@exact:delivery` to every production-source input under a change's
declared paths that no canonical spec owns: `Package.swift` and the DocC Markdown pages here (the
spec's `files:` covers Swift sources). `change supersede` accepts obligations only for a module
that is a "successor-eligible signed owner" of the entry, an exact owner is not a valid module
name, and a changed exact-only input is reported by `change audit` (and, per the binary's
diagnostics, by finalize's preflight) as "changed after acceptance and requires an audited
reopen". The prescribed remedy is `change reopen <predecessor> --actor --reason` followed by
`change correct-owner <predecessor> --all-missing --spec algorand --actor --reason`, a
human-authorized correction of the predecessor's evidence; an archived predecessor cannot be
reopened. No earlier change in this repository modified an exact-only input (verified by
recomputing every CHG-0001 and canonical-archive entry digest at each later archive tip).

## Licence boundary

No fixture was copied from an AGPL-3.0 or unlicensed upstream. The address fixture is a public
TestNet address; the mnemonic vectors are the ones the legacy suite already pins; the live probes
use freshly derived throwaway seeds and public TestNet data.
