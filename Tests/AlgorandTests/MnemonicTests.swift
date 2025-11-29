import XCTest
@testable import Algorand

final class MnemonicTests: XCTestCase {
    func testMnemonicGeneration() throws {
        let mnemonic = try Mnemonic.generate()

        let words = mnemonic.components(separatedBy: " ")
        XCTAssertEqual(words.count, 25)

        XCTAssertTrue(Mnemonic.isValid(mnemonic))
    }

    func testMnemonicRoundTrip() throws {
        let keyData = Data(repeating: 42, count: 32)
        let mnemonic = try Mnemonic.encode(keyData)
        let decoded = try Mnemonic.decode(mnemonic)

        XCTAssertEqual(keyData, decoded)
    }

    func testInvalidMnemonic() {
        XCTAssertFalse(Mnemonic.isValid("invalid mnemonic"))
        XCTAssertFalse(Mnemonic.isValid("word1 word2 word3"))

        XCTAssertThrowsError(try Mnemonic.decode("invalid mnemonic")) { error in
            guard case AlgorandError.invalidMnemonic = error else {
                XCTFail("Expected invalidMnemonic error")
                return
            }
        }
    }

    func testMnemonicValidation() throws {
        let validMnemonic = try Mnemonic.generate()
        XCTAssertTrue(Mnemonic.isValid(validMnemonic))

        // Test with tampered padding (last word should encode to zeros in padding bits)
        var words = validMnemonic.components(separatedBy: " ")
        words[24] = "ability"  // "ability" = index 1, encodes to non-zero in padding bits
        let invalidMnemonic = words.joined(separator: " ")

        XCTAssertFalse(Mnemonic.isValid(invalidMnemonic))
    }

    func testCrossSDKCompatibility() throws {
        // Test vector 1: all-zeros 32-byte key
        // Verified against py-algorand-sdk
        let zerosMnemonic = "abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon invest"
        let zerosKeyData = Data(repeating: 0, count: 32)

        XCTAssertEqual(try Mnemonic.encode(zerosKeyData), zerosMnemonic)
        XCTAssertEqual(try Mnemonic.decode(zerosMnemonic), zerosKeyData)
        XCTAssertTrue(Mnemonic.isValid(zerosMnemonic))

        // Test vector 2: all-42s 32-byte key
        // Verified against py-algorand-sdk: mn._from_key(bytes([42] * 32))
        let key42sMnemonic = "earn post bench pencil february melody eyebrow clay earn post bench pencil february melody eyebrow clay earn post bench pencil february melody eyebrow ability tired"
        let key42sData = Data(repeating: 42, count: 32)

        XCTAssertEqual(try Mnemonic.encode(key42sData), key42sMnemonic)
        XCTAssertEqual(try Mnemonic.decode(key42sMnemonic), key42sData)
        XCTAssertTrue(Mnemonic.isValid(key42sMnemonic))
    }

    func testMultipleGeneratedMnemonicsAreValid() throws {
        // Generate multiple mnemonics and verify they all pass validation
        for _ in 0..<10 {
            let mnemonic = try Mnemonic.generate()
            XCTAssertTrue(Mnemonic.isValid(mnemonic), "Generated mnemonic should be valid")

            // Verify round-trip
            let keyData = try Mnemonic.decode(mnemonic)
            let reencoded = try Mnemonic.encode(keyData)
            XCTAssertEqual(mnemonic, reencoded, "Round-trip should produce identical mnemonic")
        }
    }
}
