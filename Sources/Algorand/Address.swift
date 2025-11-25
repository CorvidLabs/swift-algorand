@preconcurrency import Foundation
import Crypto

/// Represents an Algorand address
public struct Address: Sendable {
    /// The raw address bytes (32 bytes)
    public let bytes: Data

    /// The string representation of the address
    public let description: String

    /// Creates an address from a base32-encoded string
    /// - Parameter string: The base32-encoded address string (58 characters)
    /// - Throws: `AlgorandError.invalidAddress` if the string is invalid
    public init(string: String) throws {
        guard string.count == 58 else {
            throw AlgorandError.invalidAddress("Address must be 58 characters")
        }

        // Decode base32 (without padding)
        guard let decoded = Data(base32Encoded: string) else {
            throw AlgorandError.invalidAddress("Invalid base32 encoding")
        }

        // Address is 32 bytes + 4 byte checksum
        guard decoded.count == 36 else {
            throw AlgorandError.invalidAddress("Decoded address must be 36 bytes")
        }

        let addressBytes = decoded.prefix(32)
        let checksum = decoded.suffix(4)

        // Verify checksum
        let computedChecksum = SHA512_256.hash(data: addressBytes).suffix(4)
        guard checksum == computedChecksum else {
            throw AlgorandError.invalidAddress("Invalid checksum")
        }

        self.bytes = addressBytes
        self.description = string
    }

    /// Creates an address from raw bytes
    /// - Parameter bytes: The 32-byte address
    /// - Throws: `AlgorandError.invalidAddress` if bytes are not 32 bytes
    public init(bytes: Data) throws {
        guard bytes.count == 32 else {
            throw AlgorandError.invalidAddress("Address bytes must be exactly 32 bytes")
        }

        self.bytes = bytes

        // Compute checksum and encode to base32
        let checksum = SHA512_256.hash(data: bytes).suffix(4)
        let addressWithChecksum = bytes + checksum
        self.description = addressWithChecksum.base32EncodedString()
    }
}

// MARK: - Equatable & Hashable

extension Address: Equatable, Hashable {
    public static func == (lhs: Address, rhs: Address) -> Bool {
        lhs.bytes == rhs.bytes
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
    }
}

// MARK: - Codable

extension Address: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        try self.init(string: string)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

// MARK: - CustomStringConvertible

extension Address: CustomStringConvertible {}

// MARK: - Base32 Encoding Extension

extension Data {
    /// Decodes a base32 string (RFC 4648) without padding
    init?(base32Encoded string: String) {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let base32Chars = Array(alphabet)
        var bits = ""

        for char in string.uppercased() {
            guard let index = base32Chars.firstIndex(of: char) else {
                return nil
            }
            bits += String(index, radix: 2).leftPadding(toLength: 5, withPad: "0")
        }

        var data = Data()
        for i in stride(from: 0, to: bits.count - 7, by: 8) {
            let byte = bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: i + 8)]
            if let byteValue = UInt8(byte, radix: 2) {
                data.append(byteValue)
            }
        }

        self = data
    }

    /// Encodes data to base32 string (RFC 4648) without padding
    func base32EncodedString() -> String {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let base32Chars = Array(alphabet)
        var bits = ""

        for byte in self {
            bits += String(byte, radix: 2).leftPadding(toLength: 8, withPad: "0")
        }

        var result = ""
        for i in stride(from: 0, to: bits.count, by: 5) {
            let endIndex = Swift.min(i + 5, bits.count)
            let chunk = bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: endIndex)]
            let paddedChunk = chunk.padding(toLength: 5, withPad: "0", startingAt: 0)
            if let index = Int(paddedChunk, radix: 2) {
                result.append(base32Chars[index])
            }
        }

        return result
    }
}

extension String {
    func leftPadding(toLength: Int, withPad character: Character) -> String {
        let stringLength = self.count
        if stringLength < toLength {
            return String(repeatElement(character, count: toLength - stringLength)) + self
        }
        return self
    }
}
