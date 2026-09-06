@preconcurrency import Foundation

/// Key registration transaction for consensus participation
public struct KeyRegistrationTransaction: Transaction {
    public let sender: Address
    public let votePK: Data?  // 32 bytes
    public let selectionPK: Data?  // 32 bytes
    public let voteFirst: UInt64?
    public let voteLast: UInt64?
    public let voteKeyDilution: UInt64?
    public let nonparticipation: Bool?
    public let stateProofPK: Data?  // 64 bytes
    public let fee: MicroAlgos
    public let firstValid: UInt64
    public let lastValid: UInt64
    public let genesisID: String
    public let genesisHash: Data
    public let note: Data?
    public let lease: Data?
    public let rekeyTo: Address?

    public init(
        sender: Address,
        votePK: Data? = nil,
        selectionPK: Data? = nil,
        voteFirst: UInt64? = nil,
        voteLast: UInt64? = nil,
        voteKeyDilution: UInt64? = nil,
        nonparticipation: Bool? = nil,
        stateProofPK: Data? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) {
        self.sender = sender
        self.votePK = votePK
        self.selectionPK = selectionPK
        self.voteFirst = voteFirst
        self.voteLast = voteLast
        self.voteKeyDilution = voteKeyDilution
        self.nonparticipation = nonparticipation
        self.stateProofPK = stateProofPK
        self.fee = fee
        self.firstValid = firstValid
        self.lastValid = lastValid
        self.genesisID = genesisID
        self.genesisHash = genesisHash
        self.note = note
        self.lease = lease
        self.rekeyTo = rekeyTo
    }

    /**
     Creates a key registration from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: As in the header-field initializer.
       - votePK: As in the header-field initializer.
       - selectionPK: As in the header-field initializer.
       - voteFirst: As in the header-field initializer.
       - voteLast: As in the header-field initializer.
       - voteKeyDilution: As in the header-field initializer.
       - nonparticipation: As in the header-field initializer.
       - stateProofPK: As in the header-field initializer.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field initializer.
       - lease: As in the header-field initializer.
       - rekeyTo: As in the header-field initializer.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public init(
        sender: Address,
        votePK: Data? = nil,
        selectionPK: Data? = nil,
        voteFirst: UInt64? = nil,
        voteLast: UInt64? = nil,
        voteKeyDilution: UInt64? = nil,
        nonparticipation: Bool? = nil,
        stateProofPK: Data? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = KeyRegistrationTransaction(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: voteFirst,
            voteLast: voteLast,
            voteKeyDilution: voteKeyDilution,
            nonparticipation: nonparticipation,
            stateProofPK: stateProofPK,
            fee: MicroAlgos(params.minFee),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
        self.init(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: voteFirst,
            voteLast: voteLast,
            voteKeyDilution: voteKeyDilution,
            nonparticipation: nonparticipation,
            stateProofPK: stateProofPK,
            fee: try fee.fee(for: draft, params: params),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Encodes the transaction to canonical MessagePack format for signing

     - Parameter groupID: Optional group ID for atomic transaction groups
     - Returns: The canonical transaction bytes
     - Throws: `AlgorandError.encodingError` if encoding fails
     */
    public func encode(groupID: Data? = nil) throws -> Data {
        var fields = CanonicalTransactionFields()
        fields.setHeader(
            type: "keyreg",
            sender: sender,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            groupID: groupID
        )

        fields.set("votekey", digest: votePK)
        fields.set("selkey", digest: selectionPK)
        fields.set("sprfkey", digest: stateProofPK)
        fields.set("votefst", uint: voteFirst ?? 0)
        fields.set("votelst", uint: voteLast ?? 0)
        fields.set("votekd", uint: voteKeyDilution ?? 0)
        fields.set("nonpart", bool: nonparticipation ?? false)

        return try fields.encoded()
    }
}

// MARK: - Convenience Constructors

extension KeyRegistrationTransaction {
    /// Registers account online for consensus participation
    public static func online(
        sender: Address,
        votePK: Data,
        selectionPK: Data,
        voteFirst: UInt64,
        voteLast: UInt64,
        voteKeyDilution: UInt64,
        stateProofPK: Data? = nil,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> KeyRegistrationTransaction {
        return KeyRegistrationTransaction(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: voteFirst,
            voteLast: voteLast,
            voteKeyDilution: voteKeyDilution,
            stateProofPK: stateProofPK,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Registers account online for consensus participation, from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - votePK: As in the header-field factory.
       - selectionPK: As in the header-field factory.
       - voteFirst: As in the header-field factory.
       - voteLast: As in the header-field factory.
       - voteKeyDilution: As in the header-field factory.
       - stateProofPK: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func online(
        sender: Address,
        votePK: Data,
        selectionPK: Data,
        voteFirst: UInt64,
        voteLast: UInt64,
        voteKeyDilution: UInt64,
        stateProofPK: Data? = nil,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> KeyRegistrationTransaction {
        return try KeyRegistrationTransaction(
            sender: sender,
            votePK: votePK,
            selectionPK: selectionPK,
            voteFirst: voteFirst,
            voteLast: voteLast,
            voteKeyDilution: voteKeyDilution,
            stateProofPK: stateProofPK,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Takes account offline (stops consensus participation)
    public static func offline(
        sender: Address,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> KeyRegistrationTransaction {
        return KeyRegistrationTransaction(
            sender: sender,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Takes account offline (stops consensus participation), from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func offline(
        sender: Address,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> KeyRegistrationTransaction {
        return try KeyRegistrationTransaction(
            sender: sender,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /// Marks account as nonparticipating (permanently offline)
    public static func nonparticipating(
        sender: Address,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) -> KeyRegistrationTransaction {
        return KeyRegistrationTransaction(
            sender: sender,
            nonparticipation: true,
            fee: fee,
            firstValid: firstValid,
            lastValid: lastValid,
            genesisID: genesisID,
            genesisHash: genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }

    /**
     Marks account as nonparticipating (permanently offline), from suggested parameters and a ``FeeStrategy``.

     - Parameters:
       - sender: As in the header-field factory.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: As in the header-field factory.
       - lease: As in the header-field factory.
       - rekeyTo: As in the header-field factory.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public static func nonparticipating(
        sender: Address,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil
    ) throws -> KeyRegistrationTransaction {
        return try KeyRegistrationTransaction(
            sender: sender,
            nonparticipation: true,
            fee: fee,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo
        )
    }
}
