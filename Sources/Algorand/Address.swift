@preconcurrency import Foundation
import Crypto

/**
 Represents an Algorand address

 An address is 32 bytes rendered as 58 base32 characters over the bytes plus a 4-byte checksum.
 Only the canonical rendering is accepted: go-algorand's `UnmarshalChecksumAddress` decodes the
 string, verifies the checksum, and then rejects the input unless re-encoding the decoded bytes
 reproduces it exactly. Lowercase input and a final character carrying non-zero bits past the 288
 the 36 decoded bytes use both fail that comparison, so an `Address` that exists is a string every
 other Algorand tool also accepts, and ``description`` is always the canonical form.
 */
public struct Address: Sendable {
    /// The raw address bytes (32 bytes)
    public let bytes: Data

    /// The canonical base32 rendering of the address
    public let description: String

    /// The number of bytes in a raw address.
    private static let byteCount = 32

    /// The number of checksum bytes appended before base32 encoding.
    private static let checksumByteCount = 4

    /// The number of base32 characters in the rendered form.
    private static let stringLength = 58

    /**
     Creates an address from its canonical base32-encoded string

     - Parameter string: The 58-character base32 address, exactly as Algorand renders it
     - Throws: `AlgorandError.invalidAddress` if the string has the wrong length, is not base32,
       fails its checksum, or is not the canonical rendering of its bytes
     */
    public init(string: String) throws {
        guard string.count == Self.stringLength else {
            throw AlgorandError.invalidAddress("Address must be \(Self.stringLength) characters")
        }

        // Decode base32 (without padding)
        guard let decoded = Data(base32Encoded: string) else {
            throw AlgorandError.invalidAddress("Invalid base32 encoding")
        }

        // Address is 32 bytes + 4 byte checksum
        let decodedByteCount = Self.byteCount + Self.checksumByteCount
        guard decoded.count == decodedByteCount else {
            throw AlgorandError.invalidAddress("Decoded address must be \(decodedByteCount) bytes")
        }

        let addressBytes = Data(decoded.prefix(Self.byteCount))
        let checksum = Data(decoded.suffix(Self.checksumByteCount))

        // Verify checksum
        let computedChecksum = Data(SHA512_256.hash(data: addressBytes).suffix(Self.checksumByteCount))
        guard checksum == computedChecksum else {
            throw AlgorandError.invalidAddress("Invalid checksum")
        }

        // Verify canonical form: the decoded bytes must re-encode to the exact input. This is
        // what rejects a final character whose spare bits are set - such a string decodes to the
        // same 36 bytes and passes the checksum, but no Algorand tool will accept it.
        let canonical = decoded.base32EncodedString()
        guard canonical == string else {
            throw AlgorandError.invalidAddress("Non-canonical address encoding")
        }

        self.bytes = addressBytes
        self.description = canonical
    }

    /**
     Creates an address from raw bytes

     - Parameter bytes: The 32-byte address
     - Throws: `AlgorandError.invalidAddress` if bytes are not 32 bytes
     */
    public init(bytes: Data) throws {
        guard bytes.count == Self.byteCount else {
            throw AlgorandError.invalidAddress("Address bytes must be exactly \(Self.byteCount) bytes")
        }

        self.bytes = bytes

        // Compute checksum and encode to base32
        let checksum = SHA512_256.hash(data: bytes).suffix(Self.checksumByteCount)
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
    /// Decodes a base32 string (RFC 4648) without padding.
    ///
    /// The alphabet is the uppercase one go-algorand's `base32.StdEncoding` uses; lowercase input
    /// is rejected rather than folded. Bits past the last whole byte are dropped, so a caller that
    /// needs the canonical form re-encodes and compares, as `Address.init(string:)` does.
    init?(base32Encoded string: String) {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let base32Chars = Array(alphabet)
        var bits = ""

        for char in string {
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
