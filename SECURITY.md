# Security Policy

This document covers vulnerabilities **in swift-algorand itself**. For guidance on using
the SDK safely in your own application, see
[documentation/SECURITY.md](documentation/SECURITY.md).

## Reporting a Vulnerability

Report privately through GitHub Private Vulnerability Reporting, which is enabled on this
repository:

**https://github.com/CorvidLabs/swift-algorand/security/advisories/new**

That form creates a draft advisory visible only to you and the maintainers. It is the only
supported channel - there is no security mailing address.

Please do **not** open a public issue or pull request for a suspected vulnerability, and
please do not disclose publicly until a fix has shipped or the timeline below has elapsed.

### What to include

- The affected version or commit
- Platform and Swift toolchain version
- A description of the impact - what an attacker gains
- Steps to reproduce, ideally a minimal Swift snippet or failing test
- Any proposed fix, if you have one

### Response timeline

| Stage | Target |
|---|---|
| Acknowledgement of your report | 3 business days |
| Initial assessment and severity triage | 7 calendar days |
| Fix released, or a dated plan if the fix is complex | 30 calendar days for high and critical severity |
| Advisory published and reporter credited | With the fix release |

If you have not heard anything within 7 calendar days, please comment on the draft advisory
to bump it. If a report goes 90 days without a fix or a written plan, you are free to
disclose publicly.

Reports are handled by the maintainers of the CorvidLabs organization. There is no bug
bounty.

## Supported Versions

The package is pre-1.0. Only the latest minor line receives security fixes; there are no
long-term support branches.

| Version | Supported |
|---|---|
| 0.3.x | Yes - current |
| 0.2.x | No |
| 0.1.x | No |

Because the package is pre-1.0, security fixes may ship in a release that also contains
breaking API changes. Pin with `.upToNextMinor(from: "0.3.2")` so a breaking `0.4.0` is not
picked up silently, and bump deliberately when you are ready to absorb the change.

## SDK Security Measures

This SDK implements several security practices for handling cryptographic key material.
Read the limitations below before relying on any of them.

### Cryptographically Secure Random Generation

Keys and random values come from platform-native cryptographic random sources:

- `Account()` generates its key with `Curve25519.Signing.PrivateKey()`, which draws from
  CryptoKit's system random source on Apple platforms and from BoringSSL's `RAND_bytes` on
  Linux, straight into the key's own storage.
- `Mnemonic.generate()` draws 32 bytes through `SecureRandom`: `SecRandomCopyBytes` on Apple
  platforms and `/dev/urandom`, the kernel's CSPRNG, on Linux.

### Key Material Is Not Publicly Reachable

`Account` holds its key as a `Curve25519.Signing.PrivateKey` inside a `private`
reference-typed box. There is no public property or method that returns the raw private key;
`publicKey` and `address` are public, the private key is not. `mnemonic()` is the one
operation that materialises the seed as bytes, and it does so on demand rather than caching
a copy.

This limits *accidental* exposure through the API surface. It is not an isolation
guarantee - see the next section.

### What Is and Is Not Guaranteed About Key Memory

The seed is never held by this package as a `Data` value. It lives in the cryptography
library's own key storage:

- **Linux**: swift-crypto's BoringSSL backend keeps the Ed25519 private key in its
  `SecureBytes` type, whose backing store overwrites itself with `memset_s` when it is
  deallocated. `memset_s` is the one clearing call an optimiser is not permitted to remove.
  The signing arithmetic is BoringSSL's, vendored inside swift-crypto.
- **Apple platforms**: swift-crypto re-exports CryptoKit, so the key is CryptoKit's. Apple's
  CryptoKit documentation states that it overwrites sensitive data during deallocation. That
  storage is not open source and this package does not verify the claim.

**Do not treat any of this as a security boundary.** It reduces how many copies of the seed
exist and how long they live; it does not isolate the key:

- Every `Data` or `String` you hand in or take out is yours. `Account(privateKey:)` reads the
  seed from your buffer, `Account(mnemonic:)` decodes the phrase into a `Data` the key copies
  from, and `mnemonic()` returns the seed in another alphabet. None of those is wiped by this
  package: Swift's `Data` and `String` are copy-on-write values and there is no way to reach
  every copy. Let them go out of scope promptly and never log or persist them.
- Nothing prevents the pages from being paged to disk or captured in a core dump while the
  key is alive.
- A process that can read this process's memory can read the key while it is in use.

Callers who need a real guarantee should keep key material outside this SDK - in a secure
enclave, an HSM, or a hardware wallet - and hand it in only for the duration of a signature.
`TransactionSigner` and `Transaction.bytesToSign(groupID:)` exist for exactly that.

### Canonical Input Only

`Address(string:)` accepts only the canonical 58-character uppercase rendering, as
go-algorand's `UnmarshalChecksumAddress` does, and `Mnemonic.decode` rejects the 255
non-canonical spellings of every key that a lenient decoder would accept. An address or
mnemonic this SDK accepts is therefore one every other Algorand tool also accepts, and a
value it renders is the only rendering of those bytes.

### Known Limitations

- **No third-party security audit.** This SDK has not undergone a formal external security
  audit. Anyone handling significant funds should treat it accordingly.
- **Key memory clearing is not a boundary.** See the section above.
- **No certificate pinning.** Clients use a default `URLSession` configuration and the
  system trust store.
- **Pre-1.0.** Security-relevant behaviour may change between minor versions.

## Best Practices for Users

When using this SDK in production:

1. **Secure mnemonic storage** - never log or persist mnemonics in plaintext
2. **Avoid environment variables for keys** - acceptable for TestNet scratch accounts, not
   for anything holding value
3. **Hardware security** - consider hardware wallets or HSMs for high-value accounts
4. **Key rotation** - implement rotation policies for long-lived applications
5. **Network security** - always use HTTPS for node connections outside localhost

See [documentation/SECURITY.md](documentation/SECURITY.md) for worked examples.

## Dependencies

This SDK uses swift-crypto for Ed25519 key handling and signing (`Curve25519.Signing`). On
Apple platforms swift-crypto is a thin wrapper over the system's CryptoKit; on Linux it
vendors BoringSSL. SHA-512/256, the hash Algorand uses for checksums and identifiers, is
implemented in this package. No other cryptographic dependency is linked.

The only other dependency is `swift-docc-plugin`, which is a build-time documentation tool
and is not linked into the library.
