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

    /**
     Creates a payment from explicit header fields.

     `fee` defaults to the certified protocol's minimum fee, with no usage surcharge, because
     nothing here says what the network charges; a note longer than 1024 bytes underpays. Prefer
     ``init(sender:receiver:amount:fee:params:validRounds:note:lease:rekeyTo:closeRemainderTo:)``,
     which prices a ``FeeStrategy`` against suggested parameters.
     */
    public init(
        sender: Address,
        receiver: Address,
        amount: MicroAlgos,
        fee: MicroAlgos = AlgorandConsensus.v42.minimumFee,
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

    /**
     Creates a payment from suggested parameters, pricing its fee with a ``FeeStrategy``.

     The validity window, genesis ID, and genesis hash come from `params`; the fee is
     `fee.fee(for:params:)` over a draft of this transaction carrying `min-fee`.

     - Parameters:
       - sender: The sending address.
       - receiver: The receiving address.
       - amount: The amount to send.
       - fee: How to price the fee. Defaults to ``FeeStrategy/minimum``.
       - params: The suggested parameters from ``AlgodClient/transactionParams()``.
       - validRounds: How many rounds past the first the transaction stays valid; at most 1000.
       - note: The optional note.
       - lease: The optional 32-byte lease.
       - rekeyTo: The optional rekey target.
       - closeRemainderTo: The optional close-to address.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit, or `AlgorandError` if the
       validity window overflows or the draft cannot be encoded.
     */
    public init(
        sender: Address,
        receiver: Address,
        amount: MicroAlgos,
        fee: FeeStrategy = .minimum,
        params: TransactionParams,
        validRounds: UInt64 = 1000,
        note: Data? = nil,
        lease: Data? = nil,
        rekeyTo: Address? = nil,
        closeRemainderTo: Address? = nil
    ) throws {
        let window = try params.validityWindow(rounds: validRounds)
        let draft = PaymentTransaction(
            sender: sender,
            receiver: receiver,
            amount: amount,
            fee: MicroAlgos(params.minFee),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            closeRemainderTo: closeRemainderTo
        )
        self.init(
            sender: sender,
            receiver: receiver,
            amount: amount,
            fee: try fee.fee(for: draft, params: params),
            firstValid: window.first,
            lastValid: window.last,
            genesisID: params.genesisID,
            genesisHash: params.genesisHash,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            closeRemainderTo: closeRemainderTo
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
            type: "pay",
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

        fields.set("amt", uint: amount.value)
        fields.set("rcv", address: receiver)
        fields.set("close", address: closeRemainderTo)

        return try fields.encoded()
    }
}

/**
 Builder for payment transactions

 The builder holds a ``FeeStrategy``, ``FeeStrategy/minimum`` unless one of the `fee(_:)` overloads
 says otherwise, and resolves it against the parameters given to ``params(_:)`` when ``build()``
 runs.
 */
public struct PaymentTransactionBuilder {
    private var sender: Address?
    private var receiver: Address?
    private var amount: MicroAlgos?
    private var feeStrategy: FeeStrategy = .minimum
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

    /// Pins an exact fee: shorthand for the ``FeeStrategy`` overload with ``FeeStrategy/flat(_:)``.
    /// - Parameter fee: The fee to carry verbatim.
    public func fee(_ fee: MicroAlgos) -> Self {
        self.fee(.flat(fee))
    }

    /// Chooses how the fee is priced against the parameters. Defaults to ``FeeStrategy/minimum``.
    /// - Parameter strategy: The strategy.
    public func fee(_ strategy: FeeStrategy) -> Self {
        var builder = self
        builder.feeStrategy = strategy
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

    /**
     Builds the payment, pricing its fee against the parameters.

     - Returns: The payment.
     - Throws: `AlgorandError.invalidTransaction` if a required field is missing or the validity
       window overflows, or ``FeeError/overflow(_:)`` if the fee does not fit.
     */
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

        return try PaymentTransaction(
            sender: sender,
            receiver: receiver,
            amount: amount,
            fee: feeStrategy,
            params: params,
            validRounds: validRounds,
            note: note,
            lease: lease,
            rekeyTo: rekeyTo,
            closeRemainderTo: closeRemainderTo
        )
    }
}
