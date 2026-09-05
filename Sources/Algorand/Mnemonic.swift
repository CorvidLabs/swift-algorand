@preconcurrency import Foundation
import Crypto

/**
 Generates and validates 25-word Algorand mnemonics

 A 32-byte key is packed little-endian into 24 eleven-bit words, and a 25th checksum word carries
 the first eleven bits of `SHA512-256(key)`. 24 words hold 264 bits but the key is 256, so eight
 bits are spare; only the spelling that leaves them zero is canonical. py-algorand-sdk and
 go-algorand reject the other 255 spellings of every key, and so does ``decode(_:)``.
 */
public enum Mnemonic {
    /// The number of words in a mnemonic, including the checksum word.
    private static let wordCount = 25

    /// The number of words that carry key bits.
    private static let keyWordCount = 24

    /// The key size in bytes.
    private static let keyByteCount = 32

    /// The number of bytes 24 eleven-bit words unpack to: ceil(24 * 11 / 8).
    private static let unpackedByteCount = 33

    /**
     Generates a random 25-word mnemonic

     - Returns: A 25-word mnemonic string
     - Throws: `AlgorandError.encodingError` if key data is invalid
     */
    public static func generate() throws -> String {
        // Generate 32 cryptographically secure random bytes
        let keyData = try SecureRandom.bytes(count: keyByteCount)

        return try encode(keyData)
    }

    /**
     Encodes key data into a 25-word mnemonic

     - Parameter keyData: 32 bytes of key data
     - Returns: A 25-word mnemonic string
     - Throws: `AlgorandError.encodingError` if key data is not 32 bytes
     */
    public static func encode(_ keyData: Data) throws -> String {
        guard keyData.count == keyByteCount else {
            throw AlgorandError.encodingError("Key data must be \(keyByteCount) bytes")
        }

        let wordlist = BIP39Wordlist.english

        // Convert key data to 11-bit words using little-endian bit packing
        // This matches the Algorand SDK implementation
        let keyWords = toElevenBit(Array(keyData))

        // Compute checksum: first 11 bits of SHA512/256 hash (little-endian)
        let checksumHash = SHA512_256.hash(data: keyData)
        let checksumWords = toElevenBit(Array(checksumHash.prefix(2)))
        guard let checksumWord = checksumWords.first else {
            throw AlgorandError.encodingError("Failed to derive mnemonic checksum")
        }

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

     Strict: the eight spare bits the 24 key words carry beyond the 32-byte key must be zero. A
     mnemonic that decodes to a valid key and checksum but spells the key non-canonically is
     rejected, as py-algorand-sdk's `to_private_key` and go-algorand reject it.

     - Parameter mnemonic: The 25-word mnemonic string
     - Returns: 32 bytes of key data
     - Throws: `AlgorandError.invalidMnemonic` if the mnemonic is invalid or non-canonical
     */
    public static func decode(_ mnemonic: String) throws -> Data {
        let words = mnemonic.components(separatedBy: " ")
        guard words.count == wordCount else {
            throw AlgorandError.invalidMnemonic("Mnemonic must contain exactly \(wordCount) words")
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
        let keyIndices = Array(indices.prefix(keyWordCount))
        let checksumIndex = indices[keyWordCount]

        // Unpack every bit the 24 words carry - 33 bytes - so the spare byte can be checked.
        let unpacked = fromElevenBit(keyIndices)
        guard unpacked.count == unpackedByteCount else {
            throw AlgorandError.invalidMnemonic("Mnemonic did not unpack to \(unpackedByteCount) bytes")
        }
        guard unpacked[keyByteCount] == 0 else {
            throw AlgorandError.invalidMnemonic(
                "Non-canonical mnemonic: the key words carry bits beyond the \(keyByteCount)-byte key"
            )
        }

        let keyData = Data(unpacked.prefix(keyByteCount))

        // Verify checksum
        let checksumHash = SHA512_256.hash(data: keyData)
        let expectedChecksumWords = toElevenBit(Array(checksumHash.prefix(2)))
        guard let expectedChecksum = expectedChecksumWords.first else {
            throw AlgorandError.invalidMnemonic("Failed to derive mnemonic checksum")
        }

        guard checksumIndex == expectedChecksum else {
            throw AlgorandError.invalidMnemonic("Invalid checksum")
        }

        return keyData
    }

    /// Converts 11-bit numbers back to bytes using little-endian bit unpacking, emitting every
    /// bit the words carry rather than stopping at a fixed byte count. This is the inverse of
    /// toElevenBit; for 24 words it produces 33 bytes, the last of which is the spare byte.
    private static func fromElevenBit(_ indices: [Int]) -> [UInt8] {
        var buffer: UInt32 = 0
        var numBits = 0
        var output: [UInt8] = []

        for index in indices {
            buffer |= UInt32(index) << numBits
            numBits += 11

            while numBits >= 8 {
                output.append(UInt8(buffer & 0xFF))
                buffer >>= 8
                numBits -= 8
            }
        }

        if numBits > 0 {
            output.append(UInt8(buffer & 0xFF))
        }

        return output
    }

    /**
     Validates a mnemonic

     - Parameter mnemonic: The mnemonic to validate
     - Returns: `true` if the mnemonic is valid and canonical
     */
    public static func isValid(_ mnemonic: String) -> Bool {
        do {
            _ = try decode(mnemonic)
            return true
        } catch {
            return false
        }
    }
}
