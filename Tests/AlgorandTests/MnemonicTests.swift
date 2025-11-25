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

        // Test with tampered padding (word 24 should encode to zeros)
        var words = validMnemonic.components(separatedBy: " ")
        words[24] = "ability"  // "ability" = index 1, encodes to non-zero
        let invalidMnemonic = words.joined(separator: " ")

        XCTAssertFalse(Mnemonic.isValid(invalidMnemonic))
    }
}
