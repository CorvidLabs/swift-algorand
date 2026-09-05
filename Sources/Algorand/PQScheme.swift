@preconcurrency import Foundation

/**
 A two-byte post-quantum account authorization scheme tag, the `sch` field of a `pqsig` envelope.

 Consensus protocol v42 introduced native post-quantum account signatures. go-algorand declares the
 tag as `protocol.PQScheme [2]byte`, so it travels as a MessagePack **binary of exactly two bytes**;
 a string or integer in that slot is a hard decode failure at the node. By convention the first byte
 names the signature family and the second a version or variant.

 The only scheme enabled on MainNet and TestNet is ``falcon1024``, whose tag is the lowercase ASCII
 `"f1"` (`protocol.PQSchemeFalcon1024 = PQScheme{'f', '1'}` in go-algorand v5.0.1-stable). Any
 other two bytes construct a value the network answers with `pq signature scheme not supported`;
 the type stays open so that a scheme added by a later consensus version can be carried without a
 new SDK release.
 */
public struct PQScheme: Sendable, Hashable {

    // MARK: - Constants

    /// Falcon-1024 under Algorand's deterministic signing profile, tag `"f1"`.
    public static let falcon1024 = PQScheme(uncheckedBytes: Data([0x66, 0x31]))

    /// The wire width of a scheme tag, in bytes.
    internal static let byteCount = 2

    // MARK: - Properties

    /// The raw two-byte tag, exactly as it is carried under `sch`.
    public let bytes: Data

    /// The size of a public key for this scheme, when the SDK knows it. `nil` disables size checks.
    internal var publicKeySize: Int? {
        self == .falcon1024 ? 1793 : nil
    }

    /**
     The largest signature this scheme can produce, when the SDK knows it.

     For Falcon-1024 this is the 1538-byte constant-time form that bounds go-algorand's decoder
     (`crypto.MaxPQSignatureSize`); the compressed form is at most 1423 bytes. Either needs a
     MessagePack `bin16` header.
     */
    internal var maximumSignatureSize: Int? {
        self == .falcon1024 ? 1538 : nil
    }

    // MARK: - Initializers

    /**
     Creates a scheme tag from exactly two bytes.

     - Parameter bytes: The two-byte tag.
     - Throws: `TransactionAuthorizationError.malformed` if `bytes` is not exactly two bytes long.
     */
    public init(bytes: Data) throws {
        guard bytes.count == Self.byteCount else {
            throw TransactionAuthorizationError.malformed(
                "Post-quantum scheme tag must be exactly \(Self.byteCount) bytes, got \(bytes.count)"
            )
        }
        self.bytes = bytes
    }

    private init(uncheckedBytes bytes: Data) {
        self.bytes = bytes
    }
}

// MARK: - CustomStringConvertible

extension PQScheme: CustomStringConvertible {
    /// The tag rendered as ASCII, for example `"f1"`.
    public var description: String {
        String(decoding: bytes, as: UTF8.self)
    }
}
