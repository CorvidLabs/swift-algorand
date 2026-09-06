@preconcurrency import Foundation

/**
 A native post-quantum authorization proof, the `pqsig` field of a signed transaction.

 Consensus protocol v42 added a fourth signature category alongside `sig`, `msig`, and `lsig`.
 Unlike an Ed25519 signature, a post-quantum proof is self-describing: it carries the scheme, the
 address salt, and the full public key, so the network derives the authorizing address from the
 proof alone and compares it with the transaction's sender or `sgnr`.

 The wire shape, keys in canonical order, mirrors go-algorand's `transactions.PQSig`:

 ```
 pqsig: {
     pk:  bin   the public key          (1793 bytes for Falcon-1024)
     sch: bin   the two-byte scheme tag ("f1")
     sig: bin   the signature           (up to 1538 bytes for Falcon-1024)
     slt: uint  the address salt,       OMITTED when zero
 }
 ```

 `slt` follows the struct's `codec:",omitempty"`: a zero salt is absent from the encoding.

 This package bundles no Falcon implementation, and neither do the official Python and JavaScript
 SDKs. Derive the address here, build the envelope here, and produce the signature through a
 ``PQSigner`` callback or your own ``TransactionSigner``.
 */
public struct PQSignature: Sendable, Hashable {

    // MARK: - Properties

    /// The post-quantum signature scheme, wire key `sch`.
    public let scheme: PQScheme

    /// The address salt the authorizing address was derived with, wire key `slt`.
    public let salt: UInt8

    /// The scheme's public key, wire key `pk`.
    public let publicKey: Data

    /// The raw signature over the transaction's signing preimage, wire key `sig`.
    public let signature: Data

    // MARK: - Initializers

    /**
     Creates a post-quantum authorization proof.

     Nothing is validated here, so a proof can be represented verbatim. Sizes and the derived
     authorizer are checked when the proof is attached to a transaction and again when the
     envelope is encoded.

     - Parameters:
       - scheme: The signature scheme.
       - salt: The address salt for `scheme` and `publicKey`.
       - publicKey: The scheme's public key.
       - signature: The signature over `"TX" || msgpack(txn)`.
     */
    public init(scheme: PQScheme, salt: UInt8, publicKey: Data, signature: Data) {
        self.scheme = scheme
        self.salt = salt
        self.publicKey = publicKey
        self.signature = signature
    }

    // MARK: - Internal Methods

    /// The account address this proof authorizes, derived from the carried scheme, salt, and key.
    internal func derivedAddress() throws -> Address {
        try Address.postQuantum(scheme: scheme, salt: salt, publicKey: publicKey)
    }

    /**
     Checks the sizes the network's decoder enforces before it verifies anything.

     - Throws: `TransactionAuthorizationError.malformed` if the signature is empty, the public key
       has the wrong size for a recognised scheme, or the signature exceeds the scheme's maximum.
     */
    internal func validateShape() throws {
        if let expected = scheme.publicKeySize, publicKey.count != expected {
            throw TransactionAuthorizationError.malformed(
                "Post-quantum public key for scheme \(scheme) must be \(expected) bytes, got \(publicKey.count)"
            )
        }

        guard !signature.isEmpty else {
            throw TransactionAuthorizationError.malformed("Post-quantum signature is empty")
        }

        if let maximum = scheme.maximumSignatureSize, signature.count > maximum {
            throw TransactionAuthorizationError.malformed(
                "Post-quantum signature for scheme \(scheme) must be at most \(maximum) bytes, got \(signature.count)"
            )
        }
    }

    /// The `pqsig` map. `slt` is omitted when zero; `MessagePackWriter` orders the keys.
    internal func messagePackValue() -> MessagePackValue {
        var fields: [String: MessagePackValue] = [
            "pk": .binary(publicKey),
            "sch": .binary(scheme.bytes),
            "sig": .binary(signature)
        ]

        if salt != 0 {
            fields["slt"] = .uint(UInt64(salt))
        }

        return .map(fields)
    }
}
