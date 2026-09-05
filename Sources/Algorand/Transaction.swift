@preconcurrency import Foundation

/// Transaction parameters from the network
public struct TransactionParams: Codable, Sendable {
    /// The consensus protocol version
    public let consensusVersion: String

    /// The minimum transaction fee (`min-fee`): the price of one unit of usage, and the value
    /// ``FeeStrategy/minimum`` derives every fee from.
    public let minFee: UInt64

    /// The node's suggested fee per byte (`fee`), in microAlgos. It is `0` whenever the transaction
    /// pool is uncongested, which is the steady state of MainNet and TestNet; only
    /// ``FeeStrategy/suggested`` reads it, and never below the minimum.
    public let fee: UInt64

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
        case fee = "fee"
        case genesisID = "genesis-id"
        case genesisHash = "genesis-hash"
        case lastRound = "last-round"
    }

    /**
     Creates transaction parameters directly, for offline construction and tests.

     - Parameters:
       - consensusVersion: The consensus protocol identifier, such as ``AlgorandConsensus/v42``'s.
       - minFee: The minimum transaction fee, `min-fee`.
       - fee: The suggested fee per byte, `fee`; `0` when the pool is uncongested.
       - genesisID: The genesis ID.
       - genesisHash: The 32-byte genesis hash.
       - lastRound: The round the parameters were fetched at, used as the first valid round.
     */
    public init(
        consensusVersion: String,
        minFee: UInt64,
        fee: UInt64 = 0,
        genesisID: String,
        genesisHash: Data,
        lastRound: UInt64
    ) {
        self.consensusVersion = consensusVersion
        self.minFee = minFee
        self.fee = fee
        self.genesisID = genesisID
        self.genesisHash = genesisHash
        self.lastRound = lastRound
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        consensusVersion = try container.decode(String.self, forKey: .consensusVersion)
        minFee = try container.decode(UInt64.self, forKey: .minFee)
        fee = try container.decodeIfPresent(UInt64.self, forKey: .fee) ?? 0
        genesisID = try container.decode(String.self, forKey: .genesisID)

        let genesisHashString = try container.decode(String.self, forKey: .genesisHash)
        guard let genesisHashData = Data(base64Encoded: genesisHashString) else {
            throw AlgorandError.decodingError("Invalid genesis hash")
        }
        genesisHash = genesisHashData

        lastRound = try container.decode(UInt64.self, forKey: .lastRound)
    }

    /// The validity window starting at ``firstRound`` and lasting `rounds` more rounds.
    /// - Parameter rounds: How many rounds past the first the transaction stays valid.
    /// - Returns: The first and last valid rounds.
    /// - Throws: `AlgorandError.invalidTransaction` if the last round does not fit in 64 bits.
    internal func validityWindow(rounds: UInt64) throws -> (first: UInt64, last: UInt64) {
        let (last, overflow) = firstRound.addingReportingOverflow(rounds)
        guard !overflow else {
            throw AlgorandError.invalidTransaction("Valid rounds \(rounds) from round \(firstRound) exceed UInt64")
        }
        return (firstRound, last)
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
     The consensus v42 fee usage of this transaction's fields, before any signature

     Every type gets one minimum fee plus the note surcharge by default; a type with priced
     fields of its own, such as ``ApplicationCallTransaction``, adds them. See ``TransactionUsage``.

     - Returns: The usage
     - Throws: ``FeeError/overflow(_:)`` if the usage does not fit in 64 bits
     */
    func feeUsage() throws -> TransactionUsage

    /**
     Encodes the transaction to MessagePack format for signing

     - Parameter groupID: Optional group ID for atomic transaction groups
     */
    func encode(groupID: Data?) throws -> Data

    /// Returns the transaction ID
    func id() throws -> String
}

extension Transaction {
    /**
     Encodes the transaction to MessagePack format for signing, outside any atomic group

     The protocol requirement takes a group ID, and a protocol requirement cannot carry a default
     argument, so this overload is what makes `encode()` callable on an `any Transaction`.

     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode() throws -> Data {
        try encode(groupID: nil)
    }

    /// Returns the transaction ID (hash of "TX" prefix + encoded transaction, base32 encoded)
    public func id() throws -> String {
        let encoded = try encode(groupID: nil)
        let prefixed = Data("TX".utf8) + encoded
        let hash = SHA512_256.hash(data: prefixed)
        // Transaction IDs use base32 encoding (same as addresses, but without checksum)
        return Data(hash).base32EncodedString()
    }
}
