@preconcurrency import Foundation

/// A signed transaction ready for submission
public struct SignedTransaction: Sendable {
    /// The original transaction
    public let transaction: any Transaction

    /// The signature
    public let signature: Data

    /// Optional group ID for atomic transaction groups
    public let groupID: Data?

    /**
     The transaction ID

     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func id() throws -> String {
        try transaction.id()
    }

    public init(transaction: any Transaction, signature: Data, groupID: Data? = nil) {
        self.transaction = transaction
        self.signature = signature
        self.groupID = groupID
    }

    /**
     Signs a transaction with an account

     - Parameters:
       - transaction: The transaction to sign
       - account: The account to sign with
       - groupID: Optional group ID for atomic transaction groups
     - Returns: A signed transaction
     */
    public static func sign(_ transaction: any Transaction, with account: Account, groupID: Data? = nil) throws -> SignedTransaction {
        let encoded = try transaction.encode(groupID: groupID)
        let prefixed = Data("TX".utf8) + encoded
        let signature = try account.sign(prefixed)

        return SignedTransaction(transaction: transaction, signature: signature, groupID: groupID)
    }

    /// Encodes the signed transaction to MessagePack format for submission
    public func encode() throws -> Data {
        // Encode the transaction first (with group ID if present)
        let txnEncoded = try transaction.encode(groupID: groupID)

        // Manually construct signed transaction with canonical ordering
        // Keys must be in alphabetical order: "sig", "txn"
        var output = Data()

        // Map header with 2 elements
        output.append(0x82) // fixmap with 2 elements

        // Key: "sig" (comes before "txn" alphabetically)
        output.append(0xA3) // fixstr with length 3
        output.append(contentsOf: "sig".utf8)

        // Value: signature as binary (64 bytes)
        output.append(0xC4) // bin8
        output.append(UInt8(signature.count))
        output.append(signature)

        // Key: "txn"
        output.append(0xA3) // fixstr with length 3
        output.append(contentsOf: "txn".utf8)

        // Value: embedded transaction MessagePack (already encoded)
        output.append(txnEncoded)

        return output
    }
}
