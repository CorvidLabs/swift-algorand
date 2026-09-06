@preconcurrency import Foundation

/**
 Represents an amount in microAlgos (1 Algo = 1,000,000 microAlgos)

 The amount is a `UInt64`. Arithmetic on it is offered in checked form — ``adding(_:)``,
 ``subtracting(_:)``, ``multiplied(by:)``, ``divided(by:)`` — each of which throws
 ``AmountError`` where the operators `+`, `-`, `*`, and `/` trap. The operators, and the
 `Double`-based ``init(algos:)``, are deprecated for that reason; ``init(checkedAlgos:)`` is the
 conversion that rejects a NaN, negative, or out-of-range value instead of aborting the process.
 */
public struct MicroAlgos: Sendable {
    /// The number of microAlgos in one Algo.
    public static let microAlgosPerAlgo: UInt64 = 1_000_000

    /// The amount in microAlgos
    public let value: UInt64

    /// Creates a MicroAlgos value
    /// - Parameter value: The amount in microAlgos
    public init(_ value: UInt64) {
        self.value = value
    }

    /**
     Creates a MicroAlgos value from Algos, trapping on input no amount can represent.

     `UInt64.init(_: Double)` aborts the process on a NaN, a negative value, or a value at or
     beyond 2^64, and a trap cannot be caught. Deprecated in favour of ``init(checkedAlgos:)``,
     which throws instead.

     - Parameter algos: The amount in Algos
     */
    @available(
        *,
        deprecated,
        message: "Use init(checkedAlgos:), which throws AmountError instead of trapping on NaN, negative, or out-of-range values"
    )
    public init(algos: Double) {
        self.value = UInt64(algos * Double(Self.microAlgosPerAlgo))
    }

    /**
     Creates a MicroAlgos value from Algos, rejecting input no amount can represent.

     The amount is scaled by 1,000,000 and rounded to the nearest microAlgo, ties to even, so a
     decimal a user typed lands on the value they meant rather than one below it.

     - Parameter checkedAlgos: The amount in Algos. Must be finite, non-negative, and less than
       2^64 microAlgos.
     - Throws: ``AmountError/notRepresentable(_:)`` if the value is NaN or infinite, negative, or
       scales to 2^64 microAlgos or more.
     */
    public init(checkedAlgos algos: Double) throws {
        guard algos.isFinite else {
            throw AmountError.notRepresentable("\(algos) Algos is not a finite number")
        }
        guard algos >= 0 else {
            throw AmountError.notRepresentable("\(algos) Algos is negative")
        }

        let scaled = (algos * Double(Self.microAlgosPerAlgo)).rounded(.toNearestOrEven)

        // 2^64 is exactly representable as a Double and `UInt64.max` rounds up to it, so
        // `scaled <= Double(UInt64.max)` would still admit a trapping value.
        guard scaled < 0x1p64 else {
            throw AmountError.notRepresentable("\(algos) Algos exceeds the range of UInt64 microAlgos")
        }

        self.value = UInt64(scaled)
    }

    /// The amount in Algos
    public var algos: Double {
        Double(value) / Double(Self.microAlgosPerAlgo)
    }
}

// MARK: - Equatable & Hashable

extension MicroAlgos: Equatable, Hashable {}

// MARK: - Comparable

extension MicroAlgos: Comparable {
    public static func < (lhs: MicroAlgos, rhs: MicroAlgos) -> Bool {
        lhs.value < rhs.value
    }
}

// MARK: - Codable

extension MicroAlgos: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(UInt64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

// MARK: - CustomStringConvertible

extension MicroAlgos: CustomStringConvertible {
    public var description: String {
        "\(algos) ALGO"
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension MicroAlgos: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.value = value
    }
}

// MARK: - Checked Arithmetic

extension MicroAlgos {
    /**
     Adds two amounts.

     - Parameter other: The amount to add.
     - Returns: The sum.
     - Throws: ``AmountError/overflow(_:)`` if the sum exceeds `UInt64.max`.
     */
    public func adding(_ other: MicroAlgos) throws -> MicroAlgos {
        let (sum, overflow) = value.addingReportingOverflow(other.value)
        guard !overflow else {
            throw AmountError.overflow("\(value) + \(other.value) microAlgos exceeds UInt64")
        }
        return MicroAlgos(sum)
    }

    /**
     Subtracts an amount from this one.

     - Parameter other: The amount to subtract.
     - Returns: The difference.
     - Throws: ``AmountError/overflow(_:)`` if `other` is larger than this amount.
     */
    public func subtracting(_ other: MicroAlgos) throws -> MicroAlgos {
        let (difference, overflow) = value.subtractingReportingOverflow(other.value)
        guard !overflow else {
            throw AmountError.overflow("\(value) - \(other.value) microAlgos is negative")
        }
        return MicroAlgos(difference)
    }

    /**
     Multiplies this amount by a scalar.

     - Parameter multiplier: The scalar.
     - Returns: The product.
     - Throws: ``AmountError/overflow(_:)`` if the product exceeds `UInt64.max`.
     */
    public func multiplied(by multiplier: UInt64) throws -> MicroAlgos {
        let (product, overflow) = value.multipliedReportingOverflow(by: multiplier)
        guard !overflow else {
            throw AmountError.overflow("\(value) microAlgos * \(multiplier) exceeds UInt64")
        }
        return MicroAlgos(product)
    }

    /**
     Divides this amount by a scalar, rounding toward zero.

     - Parameter divisor: The scalar.
     - Returns: The quotient.
     - Throws: ``AmountError/divisionByZero`` if `divisor` is zero.
     */
    public func divided(by divisor: UInt64) throws -> MicroAlgos {
        guard divisor != 0 else { throw AmountError.divisionByZero }
        return MicroAlgos(value / divisor)
    }
}

// MARK: - Deprecated Operators

extension MicroAlgos {
    /// Trapping addition. Deprecated: use ``adding(_:)``, which throws on overflow.
    @available(*, deprecated, message: "Use adding(_:), which throws AmountError.overflow instead of trapping")
    public static func + (lhs: MicroAlgos, rhs: MicroAlgos) -> MicroAlgos {
        MicroAlgos(lhs.value + rhs.value)
    }

    /// Trapping subtraction. Deprecated: use ``subtracting(_:)``, which throws on underflow.
    @available(*, deprecated, message: "Use subtracting(_:), which throws AmountError.overflow instead of trapping")
    public static func - (lhs: MicroAlgos, rhs: MicroAlgos) -> MicroAlgos {
        MicroAlgos(lhs.value - rhs.value)
    }

    /// Trapping multiplication. Deprecated: use ``multiplied(by:)``, which throws on overflow.
    @available(*, deprecated, message: "Use multiplied(by:), which throws AmountError.overflow instead of trapping")
    public static func * (lhs: MicroAlgos, rhs: UInt64) -> MicroAlgos {
        MicroAlgos(lhs.value * rhs)
    }

    /// Trapping division. Deprecated: use ``divided(by:)``, which throws on a zero divisor.
    @available(*, deprecated, message: "Use divided(by:), which throws AmountError.divisionByZero instead of trapping")
    public static func / (lhs: MicroAlgos, rhs: UInt64) -> MicroAlgos {
        MicroAlgos(lhs.value / rhs)
    }
}
