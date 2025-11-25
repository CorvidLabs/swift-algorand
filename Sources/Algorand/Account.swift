@preconcurrency import Foundation
import Crypto

/// Secure container for private key data that zeros memory on deallocation
private final class SecureKeyData: @unchecked Sendable {
    private var storage: Data

    init(_ data: Data) {
        self.storage = data
    }

    var data: Data {
        storage
    }

    deinit {
        // Zero out the private key memory before deallocation
        let count = storage.count
        storage.withUnsafeMutableBytes { ptr in
            if let baseAddress = ptr.baseAddress {
                memset(baseAddress, 0, count)
            }
        }
    }
}

/// Represents an Algorand account with a key pair
public struct Account: Sendable {
    /// The account's address
    public let address: Address

    /// The private key (32 bytes) - securely wiped on deallocation
    private let privateKeyContainer: SecureKeyData

    /// The public key (32 bytes)
    public let publicKey: Data

    /**
     Creates a new random account.

     This initializer generates cryptographically random keys.

     - Throws: `AlgorandError.encodingError` if key derivation fails
     */
    public init() throws {
        // Generate 32 random bytes for the private key using system RNG
        var privateKeyData = Data(count: 32)
        for i in 0..<32 {
            privateKeyData[i] = UInt8.random(in: 0...255)
        }

        // Derive public key from private key (Ed25519)
        let publicKeyData = try Self.derivePublicKey(from: privateKeyData)

        self.privateKeyContainer = SecureKeyData(privateKeyData)
        self.publicKey = publicKeyData
        self.address = try Address(bytes: publicKeyData)
    }

    /// Creates an account from a mnemonic
    /// - Parameter mnemonic: The 25-word mnemonic
    /// - Throws: `AlgorandError.invalidMnemonic` if the mnemonic is invalid
    public init(mnemonic: String) throws {
        let privateKeyData = try Mnemonic.decode(mnemonic)
        let publicKeyData = try Self.derivePublicKey(from: privateKeyData)

        self.privateKeyContainer = SecureKeyData(privateKeyData)
        self.publicKey = publicKeyData
        self.address = try Address(bytes: publicKeyData)
    }

    /// Creates an account from a private key
    /// - Parameter privateKey: The 32-byte private key
    /// - Throws: `AlgorandError.encodingError` if the key is invalid
    public init(privateKey: Data) throws {
        guard privateKey.count == 32 else {
            throw AlgorandError.encodingError("Private key must be 32 bytes")
        }

        let publicKeyData = try Self.derivePublicKey(from: privateKey)

        self.privateKeyContainer = SecureKeyData(privateKey)
        self.publicKey = publicKeyData
        self.address = try Address(bytes: publicKeyData)
    }

    /// The account's mnemonic
    /// - Throws: `AlgorandError.encodingError` if encoding fails
    public func mnemonic() throws -> String {
        try Mnemonic.encode(privateKeyContainer.data)
    }

    /// Signs data with the account's private key
    /// - Parameter data: The data to sign
    /// - Returns: The signature (64 bytes)
    public func sign(_ data: Data) throws -> Data {
        guard let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKeyContainer.data) else {
            throw AlgorandError.encodingError("Failed to create signing key")
        }

        return try Data(signingKey.signature(for: data))
    }

    /// Verifies a signature
    /// - Parameters:
    ///   - signature: The signature to verify
    ///   - data: The data that was signed
    /// - Returns: `true` if the signature is valid
    public func verify(signature: Data, for data: Data) -> Bool {
        guard let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: self.publicKey) else {
            return false
        }

        return publicKey.isValidSignature(signature, for: data)
    }

    // MARK: - Private

    /// Derives the public key from a private key using Ed25519
    /// - Parameter privateKey: The 32-byte private key
    /// - Returns: The derived public key
    /// - Throws: `AlgorandError.encodingError` if key derivation fails
    private static func derivePublicKey(from privateKey: Data) throws -> Data {
        guard let signingKey = try? Curve25519.Signing.PrivateKey(rawRepresentation: privateKey) else {
            throw AlgorandError.encodingError("Failed to create Ed25519 signing key from private key")
        }
        return signingKey.publicKey.rawRepresentation
    }
}

// MARK: - CustomStringConvertible

extension Account: CustomStringConvertible {
    public var description: String {
        address.description
    }
}
