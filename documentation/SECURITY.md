# Security Best Practices

When working with blockchain applications, security is paramount. This guide covers best practices for using the Algorand SDK securely.

## Private Key Management

### Never Hardcode Mnemonics

```swift
// ❌ NEVER DO THIS
let mnemonic = "word1 word2 word3..." // Hardcoded mnemonic

// ✅ DO THIS
// Store in Keychain or environment variable
let mnemonic = ProcessInfo.processInfo.environment["ALGO_MNEMONIC"]
guard let mnemonic = mnemonic else {
    fatalError("Mnemonic not found in environment")
}
let account = try Account(mnemonic: mnemonic)
```

### Use Keychain for iOS/macOS

```swift
import Security

func saveMnemonicToKeychain(_ mnemonic: String, account: String) throws {
    let data = mnemonic.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecValueData as String: data
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
        throw NSError(domain: "Keychain", code: Int(status))
    }
}

func loadMnemonicFromKeychain(account: String) throws -> String {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let mnemonic = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "Keychain", code: Int(status))
    }

    return mnemonic
}
```

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

### Set Appropriate Transaction Validity

```swift
// Default is 1000 rounds (~50 minutes)
let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(amount)
    .params(params)
    .validRounds(100)  // Only valid for ~5 minutes
    .build()
```

### Use Transaction Leases for Protection

Leases prevent duplicate transactions:

```swift
let lease = Data(repeating: 0, count: 32)  // Use unique lease per transaction type

let transaction = try PaymentTransactionBuilder()
    .sender(account.address)
    .receiver(receiver)
    .amount(amount)
    .params(params)
    .lease(lease)
    .build()
```

## Network Security

### Always Use HTTPS

```swift
// ✅ Secure
let algod = try AlgodClient(baseURL: "https://testnet-api.algonode.cloud")

// ❌ Insecure
let algod = try AlgodClient(baseURL: "http://insecure-node.com")
```

### Validate SSL Certificates

For production applications, implement certificate pinning.

### Use Trusted Node Providers

Only connect to trusted Algorand nodes:
- Algorand's official nodes
- Reputable node providers (AlgoNode, PureStake)
- Your own verified node infrastructure

## Error Handling

### Don't Expose Sensitive Information

```swift
// ❌ NEVER DO THIS
catch {
    print("Error with account \(account.mnemonic): \(error)")
}

// ✅ DO THIS
catch {
    print("Transaction failed: \(error.localizedDescription)")
    // Log to secure logging service without sensitive data
}
```

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

Keep your test and production accounts completely separate.

## Checklist

Before deploying to production:

- [ ] Private keys are stored securely (Keychain, environment variables, HSM)
- [ ] No mnemonics or private keys in code or version control
- [ ] All network connections use HTTPS
- [ ] Transaction details are logged (without sensitive data)
- [ ] Error messages don't expose sensitive information
- [ ] Appropriate transaction validity periods are set
- [ ] Transaction amounts and recipients are verified before signing
- [ ] Trusted node providers are used
- [ ] Separate test and production accounts
- [ ] Regular security audits are performed

## Additional Resources

- [Algorand Security Best Practices](https://developer.algorand.org/docs/get-details/security/)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Security Documentation](https://developer.apple.com/documentation/security)
