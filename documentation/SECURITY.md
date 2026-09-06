# Security Best Practices

Guidance for using this SDK safely in your own application.

> Reporting a vulnerability **in the SDK itself** is a different document: see
> [SECURITY.md at the repository root](../SECURITY.md).

## Private Key Management

The SDK reads no environment variables, no configuration files, and no keychain entries.
Every byte of key material reaches it because your code handed it over. Where that material
comes from, and how long it lives, is entirely your responsibility.

### Never Hardcode Mnemonics

```swift
// NEVER DO THIS
let mnemonic = "word1 word2 word3..."  // Hardcoded, and now in version control forever

// DO THIS - read it from somewhere your application controls
guard let mnemonic = ProcessInfo.processInfo.environment["MY_APP_ALGORAND_MNEMONIC"] else {
    throw AlgorandError.invalidMnemonic("MY_APP_ALGORAND_MNEMONIC is not set")
}
let account = try Account(mnemonic: mnemonic)
```

`MY_APP_ALGORAND_MNEMONIC` above is a name your program picks; nothing in the SDK looks for
it. Environment variables are acceptable for TestNet scratch accounts and little else -
they are visible to every child process, they land in shell history, and they are captured
by most crash reporters. For anything holding value, use the Keychain or a secret manager.

### Use Keychain for iOS/macOS

```swift
import Foundation
import Security

internal enum KeychainError: Error, Sendable {
    case encodingFailed
    case unexpectedStatus(OSStatus)
    case itemNotFound
}

internal func saveMnemonicToKeychain(_ mnemonic: String, account: String) throws {
    guard let data = mnemonic.data(using: .utf8) else {
        throw KeychainError.encodingFailed
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: data
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
        throw KeychainError.unexpectedStatus(status)
    }
}

internal func loadMnemonicFromKeychain(account: String) throws -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)

    guard status == errSecSuccess else {
        throw KeychainError.unexpectedStatus(status)
    }
    guard
        let data = item as? Data,
        let mnemonic = String(data: data, encoding: .utf8)
    else {
        throw KeychainError.itemNotFound
    }

    return mnemonic
}
```

Add `kSecAttrAccessible` to the save query to control when the item is readable -
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` is the usual choice for key material.

### Do not rely on in-process zeroing

`Account` keeps its key as a `Curve25519.Signing.PrivateKey`, never as a `Data` copy of the
seed, so the seed lives in the cryptography library's own storage: swift-crypto's
`SecureBytes` on Linux, which overwrites itself on deallocation, and CryptoKit's on Apple
platforms. Treat that as defence in depth, not a boundary. The seed you pass to
`Account(privateKey:)`, the phrase you pass to `Account(mnemonic:)`, and the phrase
`mnemonic()` returns are all your values; Swift's `Data` and `String` are copy-on-write and
nothing in the SDK can reach every copy. If an attacker can read your process memory, assume
the key is readable. Keep keys out of long-lived processes and prefer short-lived signing
contexts - or keep them out of the process entirely behind a `TransactionSigner`.

## Transaction Security

### Always Verify Transaction Details

```swift
// Build transaction
let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(amount)
    .params(params)
    .build()

// Verify before signing
print("Sending \(transaction.amount.algos) ALGO")
print("From: \(transaction.sender)")
print("To: \(transaction.receiver)")
print("Fee: \(transaction.fee.algos) ALGO")

// Get user confirmation here if needed

// Sign and submit
let signedTxn = try SignedTransaction.sign(transaction, with: account)
```

The builder does not validate that an address is one you meant, that an amount is sane, or
that a fee is reasonable. It only rejects a missing sender, receiver, amount, or params.
Every other check is yours to write.

### Set Appropriate Transaction Validity

```swift
// The builder defaults to 1000 rounds (~50 minutes at ~3s per round)
let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(amount)
    .params(params)
    .validRounds(100)  // Only valid for ~5 minutes
    .build()
```

`validRounds` is added to the params' first round to produce `lastValid`.

### Use Transaction Leases for Protection

A lease is 32 bytes that, while the transaction is valid, prevents any other transaction
from the same sender carrying the same lease. It is a duplicate-suppression tool:

```swift
// Use a value unique to the operation you are guarding, not a constant
let lease = Data(repeating: 0x01, count: 32)

let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(amount)
    .params(params)
    .lease(lease)
    .build()
```

Derive the 32 bytes from something that identifies the operation - an order ID, a hash of
the request - so that a retry of the same operation collides and a different operation does
not. A hardcoded constant shared across every transaction would block all but the first.

## Network Security

### Always Use HTTPS

```swift
// Secure
let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")

// Insecure - anything on the path can read and rewrite your transactions
let insecure = try AlgodClient(baseURL: "http://insecure-node.com")
```

Plain HTTP is fine for `http://localhost:4001` in development and nowhere else.

### Validate SSL Certificates

The clients use a default `URLSession` configuration, so they get the system trust store
and no certificate pinning. If you need pinning, put the SDK behind your own networking
layer or a proxy you control.

### Client Timeouts

Each client owns its own `URLSession` with a 30 second per-request and 60 second
per-resource timeout. Both are settable at init - lower them if a hung node must not stall
your app:

```swift
let algod = try AlgodClient(
    baseURL: "https://testnet-api.algonode.cloud",
    requestTimeout: 10,
    resourceTimeout: 20
)
```

### Use Trusted Node Providers

Only connect to nodes you trust. A malicious node can lie about balances and parameters and
can silently drop your transactions. It cannot forge your signature.

- AlgoNode / Nodely public endpoints (`*.algonode.cloud`)
- Your own node infrastructure
- A provider with an availability commitment you have read

## Error Handling

### Don't Expose Sensitive Information

```swift
// NEVER DO THIS
do {
    _ = try await algod.sendTransaction(signedTxn)
} catch {
    let phrase = try? account.mnemonic()
    print("Error with account \(phrase ?? ""): \(error)")  // key material in your logs
}

// DO THIS
do {
    _ = try await algod.sendTransaction(signedTxn)
} catch {
    print("Transaction failed: \(error.localizedDescription)")
    // Log to a secure logging service, without key material
}
```

`AlgorandError` messages carry node responses and addresses, never key material - but your
own interpolations can, so review them.

## Testing vs Production

### Use Different Accounts for Testing

```swift
#if DEBUG
let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")
#else
let algod = try AlgodClient(baseURL: "https://mainnet-api.algonode.cloud")
#endif
```

### Never Use TestNet Mnemonics on MainNet

Keep your test and production accounts completely separate. A TestNet mnemonic is a valid
MainNet key for the same address, and TestNet mnemonics leak constantly - into logs, chat,
and CI output.

## Checklist

Before deploying to production:

- [ ] Private keys are stored securely (Keychain, secret manager, HSM)
- [ ] No mnemonics or private keys in code or version control
- [ ] All network connections use HTTPS
- [ ] Transaction details are logged without key material
- [ ] Error messages don't expose sensitive information
- [ ] Appropriate transaction validity periods are set
- [ ] Amounts and recipients are verified before signing
- [ ] Trusted node providers are used
- [ ] Separate test and production accounts
- [ ] Signing on MainNet is behind an explicit confirmation step
- [ ] You have read the [Known Limitations](../SECURITY.md#known-limitations) in the
      security policy

## Additional Resources

- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Security Documentation](https://developer.apple.com/documentation/security)
- [Algorand accounts and keys](https://dev.algorand.co/concepts/accounts/overview/)
