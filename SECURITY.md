# Security

## Reporting Security Vulnerabilities

If you discover a security vulnerability in swift-algorand, please report it responsibly:

1. **Do not** open a public GitHub issue for security vulnerabilities
2. Email security concerns to the maintainers directly
3. Include detailed steps to reproduce the issue
4. Allow reasonable time for a fix before public disclosure

## SDK Security Measures

This SDK implements several security best practices for handling cryptographic key material:

### Cryptographically Secure Random Generation

All private keys and random values are generated using platform-native CSPRNGs:
- **Apple platforms**: `SecRandomCopyBytes` backed by the system's cryptographic RNG
- **Linux**: `/dev/urandom` providing the kernel's CSPRNG

### Secure Memory Handling

Private key material is protected through:
- **Secure zeroing**: Private keys are wiped from memory on deallocation using techniques designed to prevent compiler optimization from eliminating the clearing operation
- **Minimized copies**: The SDK uses closure-based access patterns (`withUnsafeBytes`) to minimize the number of copies of sensitive key material in memory

### Known Limitations

- **No third-party security audit**: This SDK has not undergone a formal third-party security audit. Users handling significant funds should consider additional security measures.
- **Swift language constraints**: Secure memory zeroing in pure Swift cannot be guaranteed to the same level as C's `memset_s` or `explicit_bzero`. The implementation uses best-effort techniques (`@inline(never)`, compiler barriers) but Swift does not provide formal guarantees against optimization.
- **Data copy-on-write**: Swift's `Data` type uses copy-on-write semantics. While the SDK minimizes copies, some transient copies may exist briefly in memory.

## Best Practices for Users

When using this SDK in production:

1. **Secure mnemonic storage**: Never log or persist mnemonics in plaintext
2. **Environment variables**: Avoid passing mnemonics via environment variables in production
3. **Hardware security**: Consider hardware wallets or HSMs for high-value accounts
4. **Key rotation**: Implement key rotation policies for long-lived applications
5. **Network security**: Always use HTTPS for node connections in production

## Dependencies

This SDK uses Apple's CryptoKit (via swift-crypto for Linux compatibility) for:
- Ed25519 signing (`Curve25519.Signing`)
- No external cryptographic dependencies beyond platform-provided libraries

## Version Support

Security updates are provided for the latest minor release. Users should stay current with releases to receive security fixes.
