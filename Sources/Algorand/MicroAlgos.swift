@preconcurrency import Foundation

/// Represents an amount in microAlgos (1 Algo = 1,000,000 microAlgos)
public struct MicroAlgos: Sendable {
    /// The amount in microAlgos
    public let value: UInt64

    /// Creates a MicroAlgos value
    /// - Parameter value: The amount in microAlgos
    public init(_ value: UInt64) {
        self.value = value
    }

    /// Creates a MicroAlgos value from Algos
    /// - Parameter algos: The amount in Algos
    public init(algos: Double) {
        self.value = UInt64(algos * 1_000_000)
    }

    /// The amount in Algos
    public var algos: Double {
        Double(value) / 1_000_000
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

// MARK: - Arithmetic Operations

extension MicroAlgos {
    public static func + (lhs: MicroAlgos, rhs: MicroAlgos) -> MicroAlgos {
        MicroAlgos(lhs.value + rhs.value)
    }

    public static func - (lhs: MicroAlgos, rhs: MicroAlgos) -> MicroAlgos {
        MicroAlgos(lhs.value - rhs.value)
    }

    public static func * (lhs: MicroAlgos, rhs: UInt64) -> MicroAlgos {
        MicroAlgos(lhs.value * rhs)
    }

    public static func / (lhs: MicroAlgos, rhs: UInt64) -> MicroAlgos {
        MicroAlgos(lhs.value / rhs)
    }
}
