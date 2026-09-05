@preconcurrency import Foundation

/**
 Fee usage under consensus v42: how many minimum fees a transaction, an envelope, or a group owes.

 v42 replaced "one minimum fee per transaction" with a usage model. Usage is a fixed-point number
 with six decimal places, go-algorand's `basics.Micros`, so `1_000_000` is exactly one minimum fee.
 A group's requirement is `ceil(usage * minFee / 1_000_000)` over the **sum** of its members' usage
 (`transactions.SummarizeFees` then `eval.CheckGroupFees`), and the network compares that with the
 sum of the members' `fee` fields. There is no per-transaction check: one member may pay for all.

 The contributions, each from go-algorand v5.0.1-stable and confirmed by a live v42 node's
 `group-usage`:

 | Source | Usage |
 |---|---|
 | every transaction (`Header.FeeContribution`) | `1_000_000` |
 | note bytes beyond 1024 | `100` per byte |
 | application-argument bytes beyond 2048, summed over all arguments | `100` per byte |
 | approval plus clear-state program bytes beyond 8192 | `100` per byte |
 | a Falcon-1024 `pqsig` envelope (`PQSchemeFeeContribution("f1")`) | `2_000_000` |

 Contributing nothing: `apep` itself, the Ed25519 signature, `sgnr`, boxes, accounts, foreign
 applications and assets, and state schemas. Logic-signature programs are priced per LogicSig
 beyond 1000 bytes; this SDK does not build logic signatures and does not model them.

 Usage is a value type with no operators: ``adding(_:)`` and ``fee(minFee:)`` throw
 ``FeeError/overflow(_:)`` rather than saturate.
 */
public struct TransactionUsage: Sendable, Hashable {

    // MARK: - Properties

    /// The usage in micro-units, where `1_000_000` is one minimum fee.
    public let micros: UInt64

    // MARK: - Initializers

    /// Creates a usage value.
    /// - Parameter micros: The usage in micro-units.
    public init(micros: UInt64) {
        self.micros = micros
    }

    // MARK: - Constants

    /// No usage: what an Ed25519 signature contributes.
    internal static let zero = TransactionUsage(micros: 0)

    /// One minimum fee: the base usage of every transaction.
    internal static let oneFee = TransactionUsage(micros: AlgorandConsensus.usageScale)

    // MARK: - Public Methods

    /**
     Adds two usages, as the network pools a group's members.

     - Parameter other: The usage to add.
     - Returns: The sum.
     - Throws: ``FeeError/overflow(_:)`` if the sum exceeds 64 bits.
     */
    public func adding(_ other: TransactionUsage) throws -> TransactionUsage {
        let (sum, overflow) = micros.addingReportingOverflow(other.micros)
        guard !overflow else {
            throw FeeError.overflow("usage \(micros) + \(other.micros) exceeds UInt64")
        }
        return TransactionUsage(micros: sum)
    }

    /**
     The fee this usage requires: `ceil(micros * minFee / 1_000_000)`.

     This is `basics.MicroAlgos.FeeForUsage` with a `1e6` multiplier and no residue, the exact
     computation `CheckGroupFees` makes for a top-level group. The product is formed at full
     128-bit width, so the only overflow is a fee that does not fit in 64 bits.

     - Parameter minFee: The network's minimum fee, ``TransactionParams/minFee`` or
       ``AlgorandConsensus/minimumFee``.
     - Returns: The smallest fee that covers this usage.
     - Throws: ``FeeError/overflow(_:)`` if the fee exceeds 64 bits.
     */
    public func fee(minFee: MicroAlgos) throws -> MicroAlgos {
        let scale = AlgorandConsensus.usageScale
        let product = micros.multipliedFullWidth(by: minFee.value)
        guard product.high < scale else {
            throw FeeError.overflow("usage \(micros) at minimum fee \(minFee.value) exceeds UInt64")
        }

        let (quotient, remainder) = scale.dividingFullWidth(product)
        guard remainder != 0 else { return MicroAlgos(quotient) }
        guard quotient < UInt64.max else {
            throw FeeError.overflow("usage \(micros) at minimum fee \(minFee.value) rounds past UInt64")
        }
        return MicroAlgos(quotient + 1)
    }

    // MARK: - Internal Methods

    /// `PerByteTxnSurcharge * max(0, byteCount - free)`, the priced portion of one field.
    internal static func surcharge(byteCount: Int, free: Int) throws -> TransactionUsage {
        guard byteCount > free else { return .zero }
        let priced = UInt64(byteCount - free)
        let (micros, overflow) = priced.multipliedReportingOverflow(by: AlgorandConsensus.perByteSurcharge)
        guard !overflow else {
            throw FeeError.overflow("\(priced) surcharged bytes exceed UInt64")
        }
        return TransactionUsage(micros: micros)
    }

    /// `Header.FeeContribution` plus the base fee: one minimum fee and the note surcharge.
    internal static func header(note: Data?) throws -> TransactionUsage {
        try oneFee.adding(try surcharge(byteCount: note?.count ?? 0, free: AlgorandConsensus.freeNoteBytes))
    }
}

// MARK: - Transactions

extension Transaction {

    /**
     This transaction's usage: one minimum fee plus the surcharge on note bytes beyond 1024.

     This is the default for every transaction type; ``ApplicationCallTransaction`` adds its
     program and argument surcharges. The signature is not part of the transaction, so a Falcon-1024
     envelope's two extra fees are added by ``SignedTransaction/feeUsage()``.

     - Returns: The usage.
     - Throws: ``FeeError/overflow(_:)`` if the arithmetic does not fit, which no well-formed
       transaction can cause.
     */
    public func feeUsage() throws -> TransactionUsage {
        try TransactionUsage.header(note: note)
    }
}

extension ApplicationCallTransaction {

    /**
     This call's usage: the header usage plus `ApplicationCallTxnFields.feeContribution`.

     Approval and clear-state program bytes are summed and priced beyond 8192 (four pages);
     argument bytes are summed over every argument and priced beyond 2048. `extraPages` raises the
     program size ceiling and costs nothing by itself, and box, account, and foreign references
     are free.

     - Returns: The usage.
     - Throws: ``FeeError/overflow(_:)`` if the arithmetic does not fit.
     */
    public func feeUsage() throws -> TransactionUsage {
        let programBytes = try Self.checkedSum([approvalProgram?.count ?? 0, clearStateProgram?.count ?? 0])
        let argumentBytes = try Self.checkedSum((appArguments ?? []).map(\.count))

        return try TransactionUsage.header(note: note)
            .adding(try TransactionUsage.surcharge(byteCount: programBytes, free: AlgorandConsensus.freeProgramBytes))
            .adding(
                try TransactionUsage.surcharge(
                    byteCount: argumentBytes,
                    free: AlgorandConsensus.freeApplicationArgumentBytes
                )
            )
    }

    /// Sums byte counts, refusing to wrap.
    private static func checkedSum(_ counts: [Int]) throws -> Int {
        var total = 0
        for count in counts {
            let (sum, overflow) = total.addingReportingOverflow(count)
            guard !overflow else { throw FeeError.overflow("byte count exceeds Int") }
            total = sum
        }
        return total
    }
}

// MARK: - Signatures

extension PQScheme {

    /// The usage an envelope authorized with this scheme adds: two minimum fees for Falcon-1024,
    /// and nothing for a scheme the network does not price, which it will reject anyway.
    public var feeUsage: TransactionUsage {
        self == .falcon1024 ? TransactionUsage(micros: AlgorandConsensus.falcon1024Usage) : .zero
    }
}

extension TransactionAuthorization {

    /// The usage this proof adds: nothing for Ed25519, the scheme's contribution for a post-quantum
    /// proof (`SignedTxn.signatureFeeContribution`).
    public var feeUsage: TransactionUsage {
        switch self {
        case .ed25519: return .zero
        case .postQuantum(let proof): return proof.scheme.feeUsage
        }
    }
}

extension SignedTransaction {

    /**
     The usage of this envelope: the transaction's usage plus the authorization's
     (`SignedTxn.FeeFactor`).

     - Returns: The usage.
     - Throws: ``FeeError/overflow(_:)`` if the sum does not fit.
     */
    public func feeUsage() throws -> TransactionUsage {
        try transaction.feeUsage().adding(authorization.feeUsage)
    }
}
