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
        fee: MicroAlgos = MicroAlgos(1000),
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

    public func encode(groupID: Data? = nil) throws -> Data {
        var map: [String: MessagePackValue] = [:]

        // Required fields
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("keyreg")

        // Key registration fields
        if let votePK = votePK {
            map["votekey"] = .binary(votePK)
        }
        if let selectionPK = selectionPK {
            map["selkey"] = .binary(selectionPK)
        }
        if let voteFirst = voteFirst {
            map["votefst"] = .uint(voteFirst)
        }
        if let voteLast = voteLast {
            map["votelst"] = .uint(voteLast)
        }
        if let voteKeyDilution = voteKeyDilution {
            map["votekd"] = .uint(voteKeyDilution)
        }
        if let nonparticipation = nonparticipation, nonparticipation {
            map["nonpart"] = .uint(1)
        }
        if let stateProofPK = stateProofPK {
            map["sprfkey"] = .binary(stateProofPK)
        }

        // Optional fields
        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let rekeyTo = rekeyTo {
            map["rekey"] = .binary(rekeyTo.bytes)
        }

        var writer = MessagePackWriter()
        return try writer.write(map: map)
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
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Takes account offline (stops consensus participation)
    public static func offline(
        sender: Address,
        fee: MicroAlgos = MicroAlgos(1000),
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

    /// Marks account as nonparticipating (permanently offline)
    public static func nonparticipating(
        sender: Address,
        fee: MicroAlgos = MicroAlgos(1000),
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
}
