@preconcurrency import Foundation
import Crypto

/// Generates and validates BIP-39 mnemonics for Algorand accounts
public enum Mnemonic {
    /**
     Generates a random 25-word mnemonic

     - Returns: A 25-word mnemonic string
     - Throws: `AlgorandError.encodingError` if key data is invalid
     */
    public static func generate() throws -> String {
        // Generate 32 random bytes using system RNG
        var keyData = Data(count: 32)
        for i in 0..<32 {
            keyData[i] = UInt8.random(in: 0...255)
        }

        return try encode(keyData)
    }

    /**
     Encodes key data into a 25-word mnemonic

     - Parameter keyData: 32 bytes of key data
     - Returns: A 25-word mnemonic string
     - Throws: `AlgorandError.encodingError` if key data is not 32 bytes
     */
    public static func encode(_ keyData: Data) throws -> String {
        guard keyData.count == 32 else {
            throw AlgorandError.encodingError("Key data must be 32 bytes")
        }

        let wordlist = BIP39Wordlist.english

        // Convert key data to 11-bit words using little-endian bit packing
        // This matches the Algorand SDK implementation
        let keyWords = toElevenBit(Array(keyData))

        // Compute checksum: first 11 bits of SHA512/256 hash (little-endian)
        let checksumHash = SHA512_256.hash(data: keyData)
        let checksumWords = toElevenBit(Array(checksumHash.prefix(2)))
        let checksumWord = checksumWords[0]

        // Build the 25-word mnemonic: 24 key words + 1 checksum word
        var words = keyWords.map { wordlist[$0] }
        words.append(wordlist[checksumWord])

        return words.joined(separator: " ")
    }

    /// Converts bytes to 11-bit numbers using little-endian bit packing
    /// This matches the Algorand SDK's _to_11_bit function
    private static func toElevenBit(_ data: [UInt8]) -> [Int] {
        var buffer: UInt32 = 0
        var numBits = 0
        var output: [Int] = []

        for byte in data {
            buffer |= UInt32(byte) << numBits
            numBits += 8

            if numBits >= 11 {
                output.append(Int(buffer & 0x7FF))
                buffer >>= 11
                numBits -= 11
            }
        }

        // Handle remaining bits
        if numBits > 0 {
            output.append(Int(buffer & 0x7FF))
        }

        return output
    }

    /**
     Decodes a 25-word mnemonic into key data

     - Parameter mnemonic: The 25-word mnemonic string
     - Returns: 32 bytes of key data
     - Throws: `AlgorandError.invalidMnemonic` if the mnemonic is invalid
     */
    public static func decode(_ mnemonic: String) throws -> Data {
        let words = mnemonic.components(separatedBy: " ")
        guard words.count == 25 else {
            throw AlgorandError.invalidMnemonic("Mnemonic must contain exactly 25 words")
        }

        let wordlist = BIP39Wordlist.english

        // Convert words to 11-bit indices
        var indices: [Int] = []
        for word in words {
            guard let index = wordlist.firstIndex(of: word.lowercased()) else {
                throw AlgorandError.invalidMnemonic("Invalid word in mnemonic: \(word)")
            }
            indices.append(index)
        }

        // First 24 words encode the key, last word is checksum
        let keyIndices = Array(indices.prefix(24))
        let checksumIndex = indices[24]

        // Convert 11-bit indices back to bytes using little-endian unpacking
        let keyData = fromElevenBit(keyIndices, byteCount: 32)

        // Verify checksum
        let checksumHash = SHA512_256.hash(data: keyData)
        let expectedChecksumWords = toElevenBit(Array(checksumHash.prefix(2)))
        let expectedChecksum = expectedChecksumWords[0]

        guard checksumIndex == expectedChecksum else {
            throw AlgorandError.invalidMnemonic("Invalid checksum")
        }

        return keyData
    }

    /// Converts 11-bit numbers back to bytes using little-endian bit unpacking
    /// This is the inverse of toElevenBit
    private static func fromElevenBit(_ indices: [Int], byteCount: Int) -> Data {
        var buffer: UInt32 = 0
        var numBits = 0
        var output: [UInt8] = []

        for index in indices {
            buffer |= UInt32(index) << numBits
            numBits += 11

            while numBits >= 8 && output.count < byteCount {
                output.append(UInt8(buffer & 0xFF))
                buffer >>= 8
                numBits -= 8
            }
        }

        // Pad with zeros if needed (shouldn't be necessary for valid input)
        while output.count < byteCount {
            output.append(0)
        }

        return Data(output)
    }

    /// Validates a mnemonic
    /// - Parameter mnemonic: The mnemonic to validate
    /// - Returns: `true` if the mnemonic is valid
    public static func isValid(_ mnemonic: String) -> Bool {
        do {
            _ = try decode(mnemonic)
            return true
        } catch {
            return false
        }
    }
}
