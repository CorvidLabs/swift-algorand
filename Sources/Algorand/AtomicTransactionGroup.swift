@preconcurrency import Foundation

/// An atomic transaction group where all transactions succeed or fail together
public struct AtomicTransactionGroup: Sendable {
    /// The transactions in this group
    public let transactions: [any Transaction]

    /// The group ID computed from the transaction hashes
    public let groupID: Data

    /// Maximum number of transactions in a group
    public static let maxGroupSize = 16

    public init(transactions: [any Transaction]) throws {
        guard !transactions.isEmpty else {
            throw AlgorandError.invalidTransaction("Transaction group cannot be empty")
        }

        guard transactions.count <= Self.maxGroupSize else {
            throw AlgorandError.invalidTransaction("Transaction group cannot contain more than \(Self.maxGroupSize) transactions")
        }

        self.transactions = transactions
        self.groupID = try Self.computeGroupID(transactions: transactions)
    }

    /// Computes the group ID from transaction hashes
    /// The group ID is SHA512-256("TG" + msgpack({"txlist": [hash1, hash2, ...]}))
    private static func computeGroupID(transactions: [any Transaction]) throws -> Data {
        // Compute the hash of each transaction
        var txHashes: [MessagePackValue] = []

        for transaction in transactions {
            // For group ID calculation, we use the hash of the encoded transaction (without group ID)
            let encoded = try transaction.encode(groupID: nil)
            let prefixed = Data("TX".utf8) + encoded
            let hash = SHA512_256.hash(data: prefixed)
            txHashes.append(.binary(hash))
        }

        // Create the TxGroup structure as MessagePack: {"txlist": [hashes...]}
        let txGroupMap: [String: MessagePackValue] = [
            "txlist": .array(txHashes)
        ]

        // Encode the TxGroup structure
        var writer = MessagePackWriter()
        let encodedTxGroup = try writer.write(map: txGroupMap)

        // Hash "TG" + encoded TxGroup
        let prefixed = Data("TG".utf8) + encodedTxGroup
        return SHA512_256.hash(data: prefixed)
    }
}

/// A signed atomic transaction group ready for submission
public struct SignedAtomicTransactionGroup: Sendable {
    /// The signed transactions in this group
    public let signedTransactions: [SignedTransaction]

    /// The group ID
    public let groupID: Data

    public init(signedTransactions: [SignedTransaction], groupID: Data) {
        self.signedTransactions = signedTransactions
        self.groupID = groupID
    }

    /// Signs all transactions in a group with the provided accounts
    /// - Parameters:
    ///   - group: The transaction group to sign
    ///   - accounts: Dictionary mapping transaction index to signing account
    /// - Returns: A signed atomic transaction group
    public static func sign(
        _ group: AtomicTransactionGroup,
        with accounts: [Int: Account]
    ) throws -> SignedAtomicTransactionGroup {
        var signedTransactions: [SignedTransaction] = []

        for (index, transaction) in group.transactions.enumerated() {
            guard let account = accounts[index] else {
                throw AlgorandError.invalidTransaction("No account provided for transaction at index \(index)")
            }

            // Sign each transaction with the group ID
            let signedTxn = try SignedTransaction.sign(transaction, with: account, groupID: group.groupID)
            signedTransactions.append(signedTxn)
        }

        return SignedAtomicTransactionGroup(
            signedTransactions: signedTransactions,
            groupID: group.groupID
        )
    }

    /// Encodes the signed transaction group for submission
    /// The format is simply concatenated encoded signed transactions (not wrapped in an array)
    public func encode() throws -> Data {
        var output = Data()

        // Concatenate each encoded signed transaction
        for signedTxn in signedTransactions {
            let encodedTxn = try signedTxn.encode()
            output.append(encodedTxn)
        }

        return output
    }
}

/// Builder for atomic transaction groups
public struct AtomicTransactionGroupBuilder {
    private var transactions: [any Transaction] = []

    public init() {}

    /// Adds a transaction to the group
    /// - Parameter transaction: The transaction to add
    /// - Returns: Self for method chaining
    public func add(_ transaction: any Transaction) -> Self {
        var builder = self
        builder.transactions.append(transaction)
        return builder
    }

    /// Adds multiple transactions to the group
    /// - Parameter transactions: The transactions to add
    /// - Returns: Self for method chaining
    public func add(_ transactions: [any Transaction]) -> Self {
        var builder = self
        builder.transactions.append(contentsOf: transactions)
        return builder
    }

    /// Builds the atomic transaction group
    /// - Returns: The constructed atomic transaction group
    /// - Throws: `AlgorandError.invalidTransaction` if the group is invalid
    public func build() throws -> AtomicTransactionGroup {
        try AtomicTransactionGroup(transactions: transactions)
    }
}
