@preconcurrency import Foundation

/**
 How a transaction's fee is chosen when it is built from suggested parameters.

 Every initializer and factory that takes ``TransactionParams`` accepts a strategy, and
 ``PaymentTransactionBuilder`` holds one. The strategy is resolved for the transaction on its own,
 as the network would price a group of one; a member of a larger group may pay more or less than
 its own share, and ``AtomicTransactionGroup/requiredFee(minFee:)`` is the authority for that.

 | Strategy | Fee |
 |---|---|
 | ``minimum`` | `ceil(usage * min-fee / 1_000_000)`, the v42 requirement for this transaction alone |
 | ``flat(_:)`` | the given amount, verbatim, including `0` for a member another member pays for |
 | ``suggested`` | `max(minimum, fee * estimated size)` from the node's per-byte `fee`; the minimum when that is `0` |

 ``minimum`` is exactly `min-fee` for an ordinary transaction and grows with priced bytes. The
 per-byte `fee` is `0` on MainNet and TestNet whenever the pool is uncongested, so ``suggested``
 usually resolves to the minimum too.
 */
public enum FeeStrategy: Sendable, Hashable {

    /// The consensus v42 requirement for this transaction alone, derived from `min-fee`.
    case minimum

    /// Exactly this fee, whatever the model says.
    case flat(MicroAlgos)

    /// The node's per-byte suggestion when it is non-zero, never below ``minimum``.
    case suggested

    // MARK: - Constants

    /// The bytes an Ed25519 envelope adds around `txn`: `0x82`, `sig`, a `bin8` header, 64 bytes
    /// of signature, and the `txn` key. The size estimate is over the signed transaction, as in
    /// the Python and JavaScript SDKs.
    internal static let signedEnvelopeOverhead: UInt64 = 75

    // MARK: - Public Methods

    /**
     Resolves this strategy for a transaction against the network's parameters.

     The transaction supplies its usage and, for ``suggested``, its encoded size; its own `fee`
     field is ignored except as part of that size, so pass a draft carrying a plausible fee.

     - Parameters:
       - transaction: The transaction to price.
       - params: The suggested parameters, for `min-fee` and the per-byte `fee`.
     - Returns: The fee to carry.
     - Throws: ``FeeError/overflow(_:)`` if the fee does not fit in 64 bits, or
       `AlgorandError.encodingError` if ``suggested`` cannot encode the transaction to size it.
     */
    public func fee(for transaction: any Transaction, params: TransactionParams) throws -> MicroAlgos {
        let minimum = try transaction.feeUsage().fee(minFee: MicroAlgos(params.minFee))

        switch self {
        case .minimum:
            return minimum
        case .flat(let fee):
            return fee
        case .suggested:
            guard params.fee != 0 else { return minimum }
            let byteCount = UInt64(try transaction.encode(groupID: nil).count) + Self.signedEnvelopeOverhead
            let (product, overflow) = params.fee.multipliedReportingOverflow(by: byteCount)
            guard !overflow else {
                throw FeeError.overflow("\(params.fee) microAlgos per byte over \(byteCount) bytes exceeds UInt64")
            }
            return Swift.max(minimum, MicroAlgos(product))
        }
    }
}
