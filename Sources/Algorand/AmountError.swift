@preconcurrency import Foundation

/**
 Failures of amount arithmetic and conversion: a result that does not fit, a division by zero, or
 a floating-point input that no integer amount can represent.

 ``MicroAlgos`` and ``AssetParams`` keep their amounts in `UInt64`, whose operators trap rather
 than throw, and a trap cannot be caught. The checked forms — ``MicroAlgos/adding(_:)``,
 ``MicroAlgos/subtracting(_:)``, ``MicroAlgos/multiplied(by:)``, ``MicroAlgos/divided(by:)``,
 ``MicroAlgos/init(checkedAlgos:)``, and ``AssetParams/baseUnits(for:)`` — throw one of these
 instead, so a caller can treat a bad amount the way it treats every other error in the SDK.
 */
public enum AmountError: Error, LocalizedError, Sendable, Equatable {

    /// A sum, difference, or product left the range of `UInt64`.
    case overflow(String)

    /// A division by zero.
    case divisionByZero

    /// A `Double` that is not finite, is negative, or scales past `UInt64.max`.
    case notRepresentable(String)

    public var errorDescription: String? {
        switch self {
        case .overflow(let detail):
            return "Amount overflow: \(detail)"
        case .divisionByZero:
            return "Amount division by zero"
        case .notRepresentable(let detail):
            return "Amount not representable: \(detail)"
        }
    }
}
