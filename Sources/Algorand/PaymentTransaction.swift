@preconcurrency import Foundation

/// A payment transaction
public struct PaymentTransaction: Transaction {
    public let sender: Address
    public let receiver: Address
    public let amount: MicroAlgos
    public let fee: MicroAlgos
    public let firstValid: UInt64
    public let lastValid: UInt64
    public let genesisID: String
    public let genesisHash: Data
    public let note: Data?
    public let lease: Data?
    public let rekeyTo: Address?
    public let closeRemainderTo: Address?

    public init(
        sender: Address,
        receiver: Address,
        amount: MicroAlgos,
        fee: MicroAlgos = MicroAlgos(1000),
        firstValid: UInt64,
        lastValid: UInt64,
        genesisID: String,
        genesisHash: Data,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil,
        closeRemainderTo: Address? = nil
    ) {
        self.sender = sender
        self.receiver = receiver
        self.amount = amount
        self.fee = fee
        self.firstValid = firstValid
        self.lastValid = lastValid
        self.genesisID = genesisID
        self.genesisHash = genesisHash
        self.note = note
        self.lease = lease
        self.rekeyTo = rekeyTo
        self.closeRemainderTo = closeRemainderTo
    }

    public func encode(groupID: Data? = nil) throws -> Data {
        // Build transaction map with Algorand's canonical field names
        var map: [String: MessagePackValue] = [:]

        // Required fields
        map["amt"] = .uint(amount.value)
        map["fee"] = .uint(fee.value)
        map["fv"] = .uint(firstValid)
        map["gen"] = .string(genesisID)
        map["gh"] = .binary(genesisHash)
        map["lv"] = .uint(lastValid)
        map["rcv"] = .binary(receiver.bytes)
        map["snd"] = .binary(sender.bytes)
        map["type"] = .string("pay")

        // Optional fields (only include if present)
        if let close = closeRemainderTo {
            map["close"] = .binary(close.bytes)
        }
        if let groupID = groupID {
            map["grp"] = .binary(groupID)
        }
        if let lease = lease {
            map["lx"] = .binary(lease)
        }
        if let note = note {
            map["note"] = .binary(note)
        }
        if let rekey = rekeyTo {
            map["rekey"] = .binary(rekey.bytes)
        }

        // Encode with canonical ordering
        var writer = MessagePackWriter()
        return try writer.write(map: map)
    }
}

/// Builder for payment transactions
public struct PaymentTransactionBuilder {
    private var sender: Address?
    private var receiver: Address?
    private var amount: MicroAlgos?
    private var fee: MicroAlgos = MicroAlgos(1000)
    private var params: TransactionParams?
    private var note: Data?
    private var lease: Data?
    private var rekeyTo: Address?
    private var closeRemainderTo: Address?
    private var validRounds: UInt64 = 1000

    public init() {}

    public func sender(_ sender: Address) -> Self {
        var builder = self
        builder.sender = sender
        return builder
    }

    public func receiver(_ receiver: Address) -> Self {
        var builder = self
        builder.receiver = receiver
        return builder
    }

    public func amount(_ amount: MicroAlgos) -> Self {
        var builder = self
        builder.amount = amount
        return builder
    }

    public func fee(_ fee: MicroAlgos) -> Self {
        var builder = self
        builder.fee = fee
        return builder
    }

    public func params(_ params: TransactionParams) -> Self {
        var builder = self
        builder.params = params
        return builder
    }

    public func note(_ note: Data) -> Self {
        var builder = self
        builder.note = note
        return builder
    }

    public func note(_ note: String) -> Self {
        var builder = self
        builder.note = note.data(using: .utf8)
        return builder
    }

    public func lease(_ lease: Data) -> Self {
        var builder = self
        builder.lease = lease
        return builder
    }

    public func rekeyTo(_ address: Address) -> Self {
        var builder = self
        builder.rekeyTo = address
        return builder
    }

    public func closeRemainderTo(_ address: Address) -> Self {
        var builder = self
        builder.closeRemainderTo = address
        return builder
    }

    public func validRounds(_ rounds: UInt64) -> Self {
        var builder = self
        builder.validRounds = rounds
        return builder
    }

    public func build() throws -> PaymentTransaction {
        guard let sender = sender else {
            throw AlgorandError.invalidTransaction("Sender is required")
        }
        guard let receiver = receiver else {
            throw AlgorandError.invalidTransaction("Receiver is required")
        }
        guard let amount = amount else {
            throw AlgorandError.invalidTransaction("Amount is required")
        }
        guard let params = params else {
            throw AlgorandError.invalidTransaction("Transaction params are required")
        }

        return PaymentTransaction(
            sender: sender,
            receiver: receiver,
            amount: amount,
            fee: fee,
            firstValid: params.firstRound,
            lastValid: params.firstRound + validRounds,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            closeRemainderTo: closeRemainderTo
        )
    }
}
