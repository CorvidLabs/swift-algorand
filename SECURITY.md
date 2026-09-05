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

All private keys and random values are generated using platform-native CSPRNGs:

- **Apple platforms**: `SecRandomCopyBytes`, backed by the system's cryptographic RNG
- **Linux**: `/dev/urandom`, the kernel's CSPRNG

### Key Material Is Not Publicly Reachable

`Account` holds its private key in a `private` reference-typed container. There is no
public property or method that returns the raw private key; `publicKey` and `address` are
public, the private key is not. `mnemonic()` re-encodes it on demand rather than caching a
copy.

This limits *accidental* exposure through the API surface. It is not an isolation
guarantee - see the next section.

### Best-effort Memory Zeroing

The private key container overwrites its buffer with `memset` when it deallocates.

**Do not treat this as a security boundary.** It is best effort and it is defeated in
practice:

- Swift's `Data` is copy-on-write, and the container hands the value out rather than
  lending a pointer. Signing constructs a `Curve25519.Signing.PrivateKey` from that value
  and `mnemonic()` passes it to the encoder; each of those, and anything Foundation or
  swift-crypto does internally, may take a buffer of its own that the wipe never reaches.
  Those copies persist until their memory happens to be reused.
- Pure Swift cannot guarantee the write survives optimization. There is no `memset_s` or
  `explicit_bzero` equivalent in the language, and the compiler is permitted to remove a
  store to memory that is never read again.
- Nothing prevents the pages from having been paged to disk or captured in a core dump
  before the wipe ran.

Callers who need a real guarantee should keep key material outside this SDK - in a secure
enclave, an HSM, or a hardware wallet - and hand it in only for the duration of a signature.

### Known Limitations

- **No third-party security audit.** This SDK has not undergone a formal external security
  audit. Anyone handling significant funds should treat it accordingly.
- **Memory zeroing is not a boundary.** See the section above.
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

This SDK uses Apple's CryptoKit (via swift-crypto for Linux compatibility) for:

- Ed25519 signing (`Curve25519.Signing`)
- No external cryptographic dependencies beyond platform-provided libraries

The only other dependency is `swift-docc-plugin`, which is a build-time documentation tool
and is not linked into the library.
