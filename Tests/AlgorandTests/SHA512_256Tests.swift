import XCTest
@testable import Algorand

final class SHA512_256Tests: XCTestCase {

    // MARK: - NIST Test Vectors
    // These test vectors are from NIST FIPS 180-4 and NIST CAVS 11.1

    func testEmptyString() throws {
        // SHA-512/256("") = c672b8d1ef56ed28ab87c3622c5114069bdd3ad7b8f9737498d0c01ecef0967a
        let data = Data()
        let hash = SHA512_256.hash(data: data)
        let expected = Data([
            0xc6, 0x72, 0xb8, 0xd1, 0xef, 0x56, 0xed, 0x28,
            0xab, 0x87, 0xc3, 0x62, 0x2c, 0x51, 0x14, 0x06,
            0x9b, 0xdd, 0x3a, 0xd7, 0xb8, 0xf9, 0x73, 0x74,
            0x98, 0xd0, 0xc0, 0x1e, 0xce, 0xf0, 0x96, 0x7a
        ])

        XCTAssertEqual(hash, expected, "Empty string hash mismatch")
    }

    func testABC() throws {
        // SHA-512/256("abc") = 53048e2681941ef99b2e29b76b4c7dabe4c2d0c634fc6d46e0e2f13107e7af23
        let data = Data("abc".utf8)
        let hash = SHA512_256.hash(data: data)
        let expected = Data([
            0x53, 0x04, 0x8e, 0x26, 0x81, 0x94, 0x1e, 0xf9,
            0x9b, 0x2e, 0x29, 0xb7, 0x6b, 0x4c, 0x7d, 0xab,
            0xe4, 0xc2, 0xd0, 0xc6, 0x34, 0xfc, 0x6d, 0x46,
            0xe0, 0xe2, 0xf1, 0x31, 0x07, 0xe7, 0xaf, 0x23
        ])

        XCTAssertEqual(hash, expected, "\"abc\" hash mismatch")
    }

    func testAbcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu() throws {
        // NIST test vector for the long string (896 bits)
        // SHA-512/256("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu")
        // = 3928e184fb8690f840da3988121d31be65cb9d3ef83ee6146feac861e19b563a
        let message = "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
        let data = Data(message.utf8)
        let hash = SHA512_256.hash(data: data)
        let expected = Data([
            0x39, 0x28, 0xe1, 0x84, 0xfb, 0x86, 0x90, 0xf8,
            0x40, 0xda, 0x39, 0x88, 0x12, 0x1d, 0x31, 0xbe,
            0x65, 0xcb, 0x9d, 0x3e, 0xf8, 0x3e, 0xe6, 0x14,
            0x6f, 0xea, 0xc8, 0x61, 0xe1, 0x9b, 0x56, 0x3a
        ])

        XCTAssertEqual(hash, expected, "Long NIST test vector hash mismatch")
    }

    func testSingleA() throws {
        // SHA-512/256("a") for a shorter test
        let data = Data("a".utf8)
        let hash = SHA512_256.hash(data: data)

        // Verify hash length is 32 bytes (256 bits)
        XCTAssertEqual(hash.count, 32, "Hash should be 32 bytes")

        // Verify determinism
        let hash2 = SHA512_256.hash(data: data)
        XCTAssertEqual(hash, hash2, "Hash should be deterministic")
    }

    func testMillionAs() throws {
        // SHA-512/256(one million 'a's) = 9a59a052930187a97038cae692f30708aa6491923ef5194394dc68d56c74fb21
        let data = Data(repeating: UInt8(ascii: "a"), count: 1_000_000)
        let hash = SHA512_256.hash(data: data)
        let expected = Data([
            0x9a, 0x59, 0xa0, 0x52, 0x93, 0x01, 0x87, 0xa9,
            0x70, 0x38, 0xca, 0xe6, 0x92, 0xf3, 0x07, 0x08,
            0xaa, 0x64, 0x91, 0x92, 0x3e, 0xf5, 0x19, 0x43,
            0x94, 0xdc, 0x68, 0xd5, 0x6c, 0x74, 0xfb, 0x21
        ])

        XCTAssertEqual(hash, expected, "One million 'a's hash mismatch")
    }

    func testBinaryData() throws {
        // Test with binary data (all bytes 0-255)
        var data = Data()
        for i in 0..<256 {
            data.append(UInt8(i))
        }

        let hash = SHA512_256.hash(data: data)

        // Verify hash length
        XCTAssertEqual(hash.count, 32, "Hash should be 32 bytes")

        // Verify determinism
        let hash2 = SHA512_256.hash(data: data)
        XCTAssertEqual(hash, hash2, "Hash should be deterministic")
    }

    func testHashLength() throws {
        // Test that all hashes are 32 bytes (256 bits)
        let testCases = [
            Data(),
            Data("a".utf8),
            Data("abc".utf8),
            Data(repeating: 0xFF, count: 1000)
        ]

        for data in testCases {
            let hash = SHA512_256.hash(data: data)
            XCTAssertEqual(hash.count, 32, "Hash length should always be 32 bytes")
        }
    }

    func testDifferentInputsProduceDifferentHashes() throws {
        let inputs = [
            Data("abc".utf8),
            Data("abd".utf8),
            Data("ABC".utf8),
            Data("ab".utf8),
            Data("abcd".utf8)
        ]

        var hashes = Set<Data>()
        for input in inputs {
            let hash = SHA512_256.hash(data: input)
            XCTAssertFalse(hashes.contains(hash), "Different inputs should produce different hashes")
            hashes.insert(hash)
        }
    }

    // MARK: - CAVS Test Vectors
    // Additional test vectors from NIST Cryptographic Algorithm Validation System

    func testCAVS_8Bit() throws {
        // 8-bit message test vector
        // Message: 0xb9
        let data = Data([0xb9])
        let hash = SHA512_256.hash(data: data)

        // SHA-512/256 of 0xb9
        // Expected: d7ac9ad478c0934bf8f719cb94e1ec965ed1c71ad0d9967f64c958975bd5e9fb
        let expected = Data([
            0xd7, 0xac, 0x9a, 0xd4, 0x78, 0xc0, 0x93, 0x4b,
            0xf8, 0xf7, 0x19, 0xcb, 0x94, 0xe1, 0xec, 0x96,
            0x5e, 0xd1, 0xc7, 0x1a, 0xd0, 0xd9, 0x96, 0x7f,
            0x64, 0xc9, 0x58, 0x97, 0x5b, 0xd5, 0xe9, 0xfb
        ])

        XCTAssertEqual(hash, expected, "CAVS 8-bit test vector mismatch")
    }

    func testCAVS_448Bit() throws {
        // 448-bit message test vector
        // Message: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        let message = "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
        let data = Data(message.utf8)
        let hash = SHA512_256.hash(data: data)

        // SHA-512/256 of this message
        // Expected: bde8e1f9f19bb9fd3406c90ec6bc47bd36d8ada9f11880dbc8a22a7078b6a461
        let expected = Data([
            0xbd, 0xe8, 0xe1, 0xf9, 0xf1, 0x9b, 0xb9, 0xfd,
            0x34, 0x06, 0xc9, 0x0e, 0xc6, 0xbc, 0x47, 0xbd,
            0x36, 0xd8, 0xad, 0xa9, 0xf1, 0x18, 0x80, 0xdb,
            0xc8, 0xa2, 0x2a, 0x70, 0x78, 0xb6, 0xa4, 0x61
        ])

        XCTAssertEqual(hash, expected, "CAVS 448-bit test vector mismatch")
    }

    // MARK: - Algorand-specific tests

    func testAddressGeneration() throws {
        // Test that our hash works correctly for address generation
        // An Algorand address is the last 4 bytes of SHA-512/256 of public key
        let publicKey = Data(repeating: 0x42, count: 32)
        let hash = SHA512_256.hash(data: publicKey)

        XCTAssertEqual(hash.count, 32, "Hash should be 32 bytes")

        // The checksum is the last 4 bytes of the hash
        let checksum = hash.suffix(4)
        XCTAssertEqual(checksum.count, 4, "Checksum should be 4 bytes")
    }

    func testTransactionIDGeneration() throws {
        // Test that our hash works correctly for transaction ID generation
        // A transaction ID is base32(SHA512-256("TX" + encoded_transaction))
        let prefix = Data("TX".utf8)
        let transaction = Data(repeating: 0x00, count: 100)
        let combined = prefix + transaction

        let hash = SHA512_256.hash(data: combined)
        XCTAssertEqual(hash.count, 32, "Transaction ID hash should be 32 bytes")
    }

    func testGroupIDGeneration() throws {
        // Test that our hash works correctly for group ID generation
        // A group ID uses "TG" prefix
        let prefix = Data("TG".utf8)
        let txHashes = Data(repeating: 0x00, count: 64) // Two 32-byte hashes
        let combined = prefix + txHashes

        let hash = SHA512_256.hash(data: combined)
        XCTAssertEqual(hash.count, 32, "Group ID hash should be 32 bytes")
    }
}
