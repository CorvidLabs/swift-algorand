@preconcurrency import Foundation

/**
 Post-quantum address derivation.

 A native post-quantum account address is not a public key. It is

 ```
 SHA512_256("PQA" || scheme[2] || salt[1] || publicKey)
 ```

 rejection-sampled over the salt so that the resulting 32 bytes can never be read as an
 Edwards25519 point (go-algorand's `basics.PQAddress` and `basics.CanonicalPQAddressSalt`). That
 keeps the post-quantum address space disjoint from the Ed25519 one: no Ed25519 key can produce a
 post-quantum address, so a post-quantum account can never be spent by an Ed25519 signature.

 The canonical salt is the **lowest** value in `0...255` whose digest is not a point, scanning
 ascending. Both halves matter: a descending scan or a different point predicate yields a different
 salt and therefore a completely different address.
 */
extension Address {

    // MARK: - Constants

    /// The domain-separation prefix for post-quantum address derivation, `protocol.PostQuantumAddress`.
    private static let postQuantumPrefix = Data("PQA".utf8)

    // MARK: - Properties

    /**
     Whether this address is eligible to be a native post-quantum account.

     True exactly when the address bytes do not decode as an Edwards25519 point, the predicate
     go-algorand's `Address.IsPQCompliant` applies.
     */
    internal var isPostQuantumCompliant: Bool {
        !Edwards25519.isPoint(bytes)
    }

    // MARK: - Public Methods

    /**
     Derives the post-quantum address for an explicit scheme, salt, and public key.

     The salt is used exactly as given; nothing checks that it is the canonical one. To derive the
     address of a key you hold, prefer ``postQuantum(scheme:publicKey:)``, which finds the canonical
     salt.

     - Parameters:
       - scheme: The post-quantum signature scheme.
       - salt: The address salt.
       - publicKey: The scheme's public key.
     - Returns: `SHA512_256("PQA" || scheme || salt || publicKey)` as an address.
     - Throws: `AlgorandError.invalidAddress` if the digest cannot form an address.
     */
    public static func postQuantum(scheme: PQScheme, salt: UInt8, publicKey: Data) throws -> Address {
        var preimage = Data()
        preimage.reserveCapacity(postQuantumPrefix.count + PQScheme.byteCount + 1 + publicKey.count)
        preimage.append(postQuantumPrefix)
        preimage.append(scheme.bytes)
        preimage.append(salt)
        preimage.append(publicKey)

        return try Address(bytes: SHA512_256.hash(data: preimage))
    }

    /**
     Derives the canonical post-quantum address and salt for a scheme and public key.

     Scans salts `0...255` ascending and returns the first whose derived address is not an
     Edwards25519 point. About half of all salts qualify, so this almost always finishes on the
     first or second try; the probability that none does is about 2^-256.

     - Parameters:
       - scheme: The post-quantum signature scheme.
       - publicKey: The scheme's public key.
     - Returns: The derived address and the canonical salt it was derived with.
     - Throws: `AlgorandError.invalidAddress` if no salt in `0...255` yields a compliant address.
     */
    public static func postQuantum(
        scheme: PQScheme,
        publicKey: Data
    ) throws -> (address: Address, salt: UInt8) {
        for candidate in UInt8.min...UInt8.max {
            let address = try postQuantum(scheme: scheme, salt: candidate, publicKey: publicKey)
            if address.isPostQuantumCompliant {
                return (address, candidate)
            }
        }

        throw AlgorandError.invalidAddress(
            "No canonical post-quantum salt exists for scheme \(scheme) and this public key"
        )
    }
}
