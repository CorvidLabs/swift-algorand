@preconcurrency import Foundation

/**
 Something that can authorize a transaction on behalf of one address.

 A signer is defined by two things: the address whose spending authority it exercises, and a way to
 turn a signing preimage into a ``TransactionAuthorization``. It never has to hold a private key in
 this process: ``PQSigner`` takes a bare `@Sendable (Data) async throws -> Data` callback, so a
 hardware wallet, a KMS, a browser extension, or a Falcon backend plugs in without this package
 seeing key material. ``Account`` conforms for the in-process Ed25519 case.

 This is the seam that makes post-quantum signing possible at all. This package does not bundle
 Falcon, and neither do the official Python and JavaScript SDKs: they derive the address, build the
 wire envelope, and delegate the signature to a caller-supplied callback. Same shape here.
 */
public protocol TransactionSigner: Sendable {

    /**
     The address whose authority this signer exercises.

     For an Ed25519 signer this is the address of its public key; for a post-quantum signer it is
     the derived post-quantum address. When it differs from a transaction's sender the transaction
     is being signed for a rekeyed account, and ``sign(_:groupID:authAddr:)`` carries it as `sgnr`.
     */
    var address: Address { get }

    /**
     Produces an authorization over exact preimage bytes.

     - Parameter bytesToSign: The signing preimage, `"TX" || msgpack(txn)`, unhashed. Sign these
       bytes verbatim; any hashing the scheme requires is the scheme's own.
     - Returns: The proof to attach to the signed transaction.
     - Throws: Whatever the backing key store throws.
     */
    func authorize(_ bytesToSign: Data) async throws -> TransactionAuthorization
}

// MARK: - Signing

extension TransactionSigner {

    /**
     Signs a transaction, attaching `sgnr` automatically when this signer is not the sender.

     The rule is go-algorand's `SignedTxn.Authorizer()`: the network checks the proof against
     `sgnr` if present, otherwise against the sender. So `sgnr` is emitted exactly when
     ``address`` differs from `transaction.sender` and omitted otherwise, which is also what the
     Python and JavaScript SDKs do, and what consensus requires: a `sgnr` equal to the sender is
     rejected outright.

     - Parameters:
       - transaction: The transaction to sign.
       - groupID: The atomic group ID, or `nil` for a standalone transaction.
       - authAddr: Optionally, the address this signer is expected to act for. It is documentation
         and a guard, not an override: when supplied it must equal ``address``.
     - Returns: The signed transaction.
     - Throws: `TransactionAuthorizationError.authAddrMismatch` if `authAddr` is not this signer's
       address; `TransactionAuthorizationError.unauthorizedProof` or `.malformed` if the proof
       cannot authorize the transaction; `AlgorandError.encodingError` if encoding fails; and
       whatever ``authorize(_:)`` throws.
     */
    public func sign(
        _ transaction: any Transaction,
        groupID: Data? = nil,
        authAddr: Address? = nil
    ) async throws -> SignedTransaction {
        let authorization = try await authorize(try transaction.bytesToSign(groupID: groupID))

        return try SignedTransaction(
            transaction: transaction,
            authorization: authorization,
            signer: address,
            authAddr: authAddr,
            groupID: groupID
        )
    }
}

// MARK: - Account

extension Account: TransactionSigner {

    /// Signs the preimage with the account's Ed25519 key.
    /// - Parameter bytesToSign: The signing preimage.
    /// - Returns: The 64-byte signature as an ``TransactionAuthorization/ed25519(_:)`` proof.
    public func authorize(_ bytesToSign: Data) async throws -> TransactionAuthorization {
        .ed25519(try sign(bytesToSign))
    }
}

// MARK: - Post-Quantum

/**
 A ``TransactionSigner`` for a native post-quantum account, backed by a caller-supplied signing
 callback.

 The signer derives the account's canonical salt and address from the public key, and wraps every
 signature the callback returns in a ``PQSignature`` carrying that scheme, salt, and key. The
 callback receives the exact preimage bytes (`"TX" || msgpack(txn)`, unhashed) and returns the raw
 signature; for Falcon-1024 that is Algorand's deterministic `det1024` profile, with a 1793-byte
 public key and a signature of at most 1538 bytes. No Falcon implementation is bundled.

 ```swift
 let signer = try PQSigner(publicKey: falconPublicKey) { bytes in
     try await falconBackend.sign(bytes)
 }
 let signed = try await signer.sign(transaction)
 ```

 - Note: A Falcon-1024 proof raises the transaction's fee usage. A consensus v42 TestNet node
   reports `group-usage: 3000000` (three minimum fees) for a single Falcon-signed payment, against
   `1000000` for the same payment under Ed25519. This package's builders still default `fee` to
   the network minimum, so set the fee explicitly when signing with a post-quantum key.
 */
public struct PQSigner: TransactionSigner {

    // MARK: - Properties

    /// The post-quantum scheme this signer uses.
    public let scheme: PQScheme

    /// The scheme's public key, carried in every proof this signer produces.
    public let publicKey: Data

    /// The canonical address salt for ``scheme`` and ``publicKey``.
    public let salt: UInt8

    /// The derived post-quantum address this signer authorizes for.
    public let address: Address

    private let signBytes: @Sendable (Data) async throws -> Data

    // MARK: - Initializers

    /**
     Creates a post-quantum signer, deriving its canonical salt and address from the public key.

     - Parameters:
       - scheme: The post-quantum scheme; ``PQScheme/falcon1024`` unless a later consensus version
         enables another.
       - publicKey: The scheme's public key.
       - sign: Signs exact preimage bytes and returns the raw signature.
     - Throws: `TransactionAuthorizationError.malformed` if the public key has the wrong size for
       a recognised scheme, or `AlgorandError.invalidAddress` if no canonical salt exists.
     */
    public init(
        scheme: PQScheme = .falcon1024,
        publicKey: Data,
        sign: @escaping @Sendable (Data) async throws -> Data
    ) throws {
        if let expected = scheme.publicKeySize, publicKey.count != expected {
            throw TransactionAuthorizationError.malformed(
                "Post-quantum public key for scheme \(scheme) must be \(expected) bytes, got \(publicKey.count)"
            )
        }

        let derived = try Address.postQuantum(scheme: scheme, publicKey: publicKey)

        self.scheme = scheme
        self.publicKey = publicKey
        self.salt = derived.salt
        self.address = derived.address
        self.signBytes = sign
    }

    // MARK: - TransactionSigner

    /// Obtains a signature from the callback and wraps it in a ``PQSignature``.
    /// - Parameter bytesToSign: The signing preimage, handed to the callback verbatim.
    /// - Returns: The ``TransactionAuthorization/postQuantum(_:)`` proof.
    /// - Throws: `TransactionAuthorizationError.malformed` if the callback returns an empty or
    ///   oversized signature, or whatever the callback throws.
    public func authorize(_ bytesToSign: Data) async throws -> TransactionAuthorization {
        let proof = PQSignature(
            scheme: scheme,
            salt: salt,
            publicKey: publicKey,
            signature: try await signBytes(bytesToSign)
        )
        try proof.validateShape()
        return .postQuantum(proof)
    }
}
