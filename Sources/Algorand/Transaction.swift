@preconcurrency import Foundation

/// Transaction parameters from the network
public struct TransactionParams: Codable, Sendable {
    /// The consensus protocol version
    public let consensusVersion: String

    /// The minimum transaction fee
    public let minFee: UInt64

    /// The genesis ID
    public let genesisID: String

    /// The genesis hash
    public let genesisHash: Data

    /// The last valid round
    public let lastRound: UInt64

    /// The first valid round (typically lastRound + 1)
    public var firstRound: UInt64 {
        lastRound
    }

    enum CodingKeys: String, CodingKey {
        case consensusVersion = "consensus-version"
        case minFee = "min-fee"
        case genesisID = "genesis-id"
        case genesisHash = "genesis-hash"
        case lastRound = "last-round"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consensusVersion = try container.decode(String.self, forKey: .consensusVersion)
        minFee = try container.decode(UInt64.self, forKey: .minFee)
        genesisID = try container.decode(String.self, forKey: .genesisID)

        let genesisHashString = try container.decode(String.self, forKey: .genesisHash)
        guard let genesisHashData = Data(base64Encoded: genesisHashString) else {
            throw AlgorandError.decodingError("Invalid genesis hash")
        }
        genesisHash = genesisHashData

        lastRound = try container.decode(UInt64.self, forKey: .lastRound)
    }
}

/// Base transaction protocol
public protocol Transaction: Sendable {
    /// The sender's address
    var sender: Address { get }

    /// The fee (in microAlgos)
    var fee: MicroAlgos { get }

    /// The first valid round
    var firstValid: UInt64 { get }

    /// The last valid round
    var lastValid: UInt64 { get }

    /// The genesis ID
    var genesisID: String { get }

    /// The genesis hash
    var genesisHash: Data { get }

    /// Optional note
    var note: Data? { get }

    /// Optional lease
    var lease: Data? { get }

    /// Optional rekey address
    var rekeyTo: Address? { get }

    /**
     Encodes the transaction to MessagePack format for signing

     - Parameter groupID: Optional group ID for atomic transaction groups
     */
    func encode(groupID: Data?) throws -> Data

    /// Returns the transaction ID
    func id() throws -> String
}

extension Transaction {
    /// Returns the transaction ID (hash of "TX" prefix + encoded transaction, base32 encoded)
    public func id() throws -> String {
        let encoded = try encode(groupID: nil)
        let prefixed = Data("TX".utf8) + encoded
        let hash = SHA512_256.hash(data: prefixed)
        // Transaction IDs use base32 encoding (same as addresses, but without checksum)
        return Data(hash).base32EncodedString()
    }
}
