---
hi: 1
families: [SIGN]
owner: leif
---

# Keys and signing

## Intent

Keys are the one thing an SDK like this must not be careless with. Creating, backing up and restoring an account should take a line each, and the key should stay inside the account unless I explicitly ask for the mnemonic. For anything that holds real value I should be able to keep the key somewhere safer, a wallet, an HSM or a KMS, and hand the SDK only the signature. Rekeyed and post-quantum accounts should work the same way, with the SDK checking what it can before the network does.

## Criteria

- **SIGN-1**  I can create an account, back it up as a 25-word mnemonic, and restore it later.
- **SIGN-2**  An address or mnemonic the SDK accepts is one every other Algorand tool accepts too.
- **SIGN-3**  The private key never leaves the account except as the mnemonic I explicitly ask for.
- **SIGN-4**  I can keep my key outside my process, in a wallet, HSM or KMS, and still sign with this SDK.
- **SIGN-5**  Spending from a rekeyed account works without me having to know the envelope rules.
- **SIGN-6**  I can sign for a post-quantum account with my own Falcon implementation.
  - **SIGN-6.a**  A post-quantum proof that cannot authorize the sender is refused before the network ever sees it.
- **SIGN-7**  Keys come from a cryptographically secure source on every platform.
