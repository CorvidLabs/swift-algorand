@preconcurrency import Foundation

/**
 Failures of the fee model: arithmetic that does not fit, and a group that does not pay enough.

 Fee arithmetic never saturates. go-algorand's `FeeForUsage` saturates *and* reports overflow, and
 the network rejects the group when it does; an SDK that silently produced `UInt64.max` would
 instead hand the caller a fee to sign. Every overflow is therefore a thrown ``overflow(_:)``.
 */
public enum FeeError: Error, LocalizedError, Sendable, Equatable {

    /// A usage sum, a fee product, or a paid-fee total exceeded 64 bits.
    case overflow(String)

    /// A signed group pays less than consensus v42 requires for its pooled usage.
    case insufficient(required: MicroAlgos, paid: MicroAlgos)

    public var errorDescription: String? {
        switch self {
        case .overflow(let detail):
            return "Fee overflow: \(detail)"
        case .insufficient(let required, let paid):
            return "Insufficient fee: the group pays \(paid.value) microAlgos but needs \(required.value)"
        }
    }
}
