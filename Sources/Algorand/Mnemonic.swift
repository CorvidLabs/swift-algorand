@preconcurrency import Foundation
import Crypto

/// Generates and validates BIP-39 mnemonics for Algorand accounts
public enum Mnemonic {
    /// Generates a random 25-word mnemonic
    /// - Returns: A 25-word mnemonic string
    /// - Throws: `AlgorandError.encodingError` if key data is invalid
    public static func generate() throws -> String {
        // Generate 32 random bytes using system RNG
        var keyData = Data(count: 32)
        for i in 0..<32 {
            keyData[i] = UInt8.random(in: 0...255)
        }

        return try encode(keyData)
    }

    /// Encodes key data into a 25-word mnemonic
    /// - Parameter keyData: 32 bytes of key data
    /// - Returns: A 25-word mnemonic string
    /// - Throws: `AlgorandError.encodingError` if key data is not 32 bytes
    public static func encode(_ keyData: Data) throws -> String {
        guard keyData.count == 32 else {
            throw AlgorandError.encodingError("Key data must be 32 bytes")
        }

        var words: [String] = []
        let wordlist = BIP39Wordlist.english

        // Convert key data to bits
        var bits = ""
        for byte in keyData {
            bits += String(byte, radix: 2).leftPadding(toLength: 8, withPad: "0")
        }

        // Algorand uses first 8 bits of SHA512/256 as checksum (not SHA256!)
        let checksum = SHA512_256.hash(data: keyData)
        let checksumByte = Array(checksum)[0]
        bits += String(checksumByte, radix: 2).leftPadding(toLength: 8, withPad: "0")

        // Now we have 264 bits (256 + 8), which gives us 24 words
        // We need exactly 25 words, so the last word encodes the remaining bits (0-padded)
        // 264 bits / 11 = 24 words, with 0 bits remaining
        // To get 25 words: 25 * 11 = 275 bits needed
        // Pad with zeros to get 275 bits
        bits += String(repeating: "0", count: 275 - bits.count)

        // Convert to 25 words (11 bits each)
        for i in stride(from: 0, to: 275, by: 11) {
            let chunk = bits[bits.index(bits.startIndex, offsetBy: i)..<bits.index(bits.startIndex, offsetBy: i + 11)]
            if let index = Int(chunk, radix: 2) {
                words.append(wordlist[index])
            }
        }

        return words.joined(separator: " ")
    }

    /// Decodes a 25-word mnemonic into key data
    /// - Parameter mnemonic: The 25-word mnemonic string
    /// - Returns: 32 bytes of key data
    /// - Throws: `AlgorandError.invalidMnemonic` if the mnemonic is invalid
    public static func decode(_ mnemonic: String) throws -> Data {
        let words = mnemonic.components(separatedBy: " ")
        guard words.count == 25 else {
            throw AlgorandError.invalidMnemonic("Mnemonic must contain exactly 25 words")
        }

        let wordlist = BIP39Wordlist.english
        var bits = ""

        for word in words {
            guard let index = wordlist.firstIndex(of: word.lowercased()) else {
                throw AlgorandError.invalidMnemonic("Invalid word in mnemonic: \(word)")
            }
            bits += String(index, radix: 2).leftPadding(toLength: 11, withPad: "0")
        }

        // Extract key data (first 256 bits)
        let keyBits = bits.prefix(256)
        var keyData = Data()
        for i in stride(from: 0, to: 256, by: 8) {
            let byte = keyBits[keyBits.index(keyBits.startIndex, offsetBy: i)..<keyBits.index(keyBits.startIndex, offsetBy: i + 8)]
            if let byteValue = UInt8(byte, radix: 2) {
                keyData.append(byteValue)
            }
        }

        // Verify checksum (8 bits at position 256-263)
        let checksumBits = String(bits[bits.index(bits.startIndex, offsetBy: 256)..<bits.index(bits.startIndex, offsetBy: 264)])
        let computedChecksum = SHA512_256.hash(data: keyData)
        let computedChecksumByte = Array(computedChecksum)[0]
        let computedChecksumBits = String(computedChecksumByte, radix: 2).leftPadding(toLength: 8, withPad: "0")

        guard checksumBits == computedChecksumBits else {
            throw AlgorandError.invalidMnemonic("Invalid checksum")
        }

        // Verify padding bits (264-274) are all zeros
        let paddingBits = String(bits[bits.index(bits.startIndex, offsetBy: 264)..<bits.index(bits.startIndex, offsetBy: 275)])
        guard paddingBits == String(repeating: "0", count: 11) else {
            throw AlgorandError.invalidMnemonic("Invalid padding")
        }

        return keyData
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
